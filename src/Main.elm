module Main exposing (main)

import Browser
import Html exposing (Html, div, text)
import Html.Attributes exposing (style)
import Random
import Browser.Events
import Json.Decode as Decode
import Process
import Task
import Basics exposing (modBy)

-- Types

type alias Position =
    { x : Int, y : Int }

type Direction
    = Up
    | Down
    | Left
    | Right

type alias Model =
    { snake : List Position
    , dir : Direction
    , food : Position
    , width : Int
    , height : Int
    , gameOver : Bool
    , collisionWarningSteps : Int
    }

init : () -> ( Model, Cmd Msg )
init _ =
    let
        initialSnake = List.map (\i -> { x = 5 - i, y = 5 }) (List.range 0 9) -- length 10
        initialDir = Right
        w = 20
        h = 20
        initialFood = { x = 10, y = 10 }
    in
    ( { snake = initialSnake
      , dir = initialDir
      , food = initialFood
      , width = w
      , height = h
      , gameOver = False
      , collisionWarningSteps = 0
      }
    , tickCmd
    )

-- Msg

type Msg
    = Tick
    | ChangeDir Direction
    | Restart
    | NewFood Position

-- Timer

tickInterval : Float
-- milliseconds

tickInterval = 150

tickCmd : Cmd Msg
tickCmd =
    Process.sleep tickInterval
        |> Task.perform (\_ -> Tick)

-- Random food generator
foodGenerator : Int -> Int -> Random.Generator Position
foodGenerator w h =
    Random.map2 Position (Random.int 0 (w - 1)) (Random.int 0 (h - 1))

-- Update

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        Tick ->
            let
                newHead =
                    case model.snake of
                        h :: _ ->
                            moveHead h model.dir
                        [] ->
                            { x = 0, y = 0 }
                ateFood = newHead.x == model.food.x && newHead.y == model.food.y
                body = model.snake
                canCollide = model.collisionWarningSteps == 0
                collided = canCollide && List.any (\p -> p.x == newHead.x && p.y == newHead.y) body
                (finalSnake, warningSteps) =
                    if collided then
                        let
                            len = List.length model.snake
                            newLen = Basics.max 1 (len - 3)
                        in
                        (List.take newLen (newHead :: model.snake), 30)
                    else if ateFood then
                        (newHead :: model.snake, Basics.max 0 (model.collisionWarningSteps - 1))
                    else
                        (newHead :: removeLast model.snake, Basics.max 0 (model.collisionWarningSteps - 1))
                cmd =
                    if ateFood then
                        Random.generate NewFood (foodGenerator model.width model.height)
                    else
                        tickCmd
            in
            ( { model | snake = finalSnake, gameOver = collided, collisionWarningSteps = warningSteps }
            , cmd
            )

        ChangeDir dir ->
            ( { model | dir = dir }, Cmd.none )

        Restart ->
            init ()

        NewFood pos ->
            ( { model | food = pos }, tickCmd )

moveHead : Position -> Direction -> Position
moveHead pos dir =
    let
        w = 20 -- grid width, should match model.width
        h = 20 -- grid height, should match model.height
        newPos =
            case dir of
                Up -> { pos | y = pos.y - 1 }
                Down -> { pos | y = pos.y + 1 }
                Left -> { pos | x = pos.x - 1 }
                Right -> { pos | x = pos.x + 1 }
    in
    { x = modBy w (newPos.x + w), y = modBy h (newPos.y + h) }

removeLast : List a -> List a
removeLast xs =
    xs
        |> List.reverse
        |> List.tail
        |> Maybe.withDefault []
        |> List.reverse

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }

subscriptions : Model -> Sub Msg
subscriptions _ =
    Browser.Events.onKeyDown keyDecoder

keyDecoder : Decode.Decoder Msg
keyDecoder =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                case key of
                    "ArrowUp" -> Decode.succeed (ChangeDir Up)
                    "ArrowDown" -> Decode.succeed (ChangeDir Down)
                    "ArrowLeft" -> Decode.succeed (ChangeDir Left)
                    "ArrowRight" -> Decode.succeed (ChangeDir Right)
                    _ -> Decode.fail "Not an arrow key"
            )

view : Model -> Html Msg
view model =
    let
        cellSize = 20
        headPos =
            case model.snake of
                h :: _ -> Just h
                [] -> Nothing
        renderCell x y =
            let
                isHead =
                    case headPos of
                        Just h -> h.x == x && h.y == y
                        Nothing -> False
                isSnake = List.any (\p -> p.x == x && p.y == y) model.snake
                isFood = model.food.x == x && model.food.y == y
                bgColor =
                    if isHead then "#2196F3"
                    else if isSnake then "#4CAF50"
                    else if isFood then "#e53935"
                    else "#eee"
            in
            div
                [ style "width" (String.fromInt cellSize ++ "px")
                , style "height" (String.fromInt cellSize ++ "px")
                , style "display" "inline-block"
                , style "background-color" bgColor
                , style "border" "1px solid #ccc"
                , style "box-sizing" "border-box"
                ]
                []
        renderRow y =
            div [] (List.map (\x -> renderCell x y) (List.range 0 (model.width - 1)))
        lengthAndCollision =
            div [ style "margin" "10px 0", style "font-size" "18px", style "display" "flex", style "align-items" "center", style "gap" "16px" ]
                ([ text ("Snake length: " ++ String.fromInt (List.length model.snake)) ] ++
                    (if model.collisionWarningSteps > 0 then
                        [ div [ style "color" "red" ] [ text "Collision!" ] ]
                     else
                        []
                    )
                )
    in
    div []
        [ lengthAndCollision
        , div [ style "user-select" "none" ]
            (List.map renderRow (List.range 0 (model.height - 1)))
        ]

posToString : Position -> String
posToString pos =
    "(" ++ String.fromInt pos.x ++ "," ++ String.fromInt pos.y ++ ")" 