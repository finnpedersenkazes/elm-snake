module Main exposing (main)

import Browser
import Html exposing (Html, div, text, button)
import Html.Attributes exposing (style, class)
import Html.Events exposing (onClick, on)
import Random
import Browser.Events
import Json.Decode as Decode
import Process
import Task
import Basics exposing (modBy)
import Browser.Dom

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
    , highScore : Int
    , paused : Bool
    , viewportWidth : Int
    , viewportHeight : Int
    }

init : () -> ( Model, Cmd Msg )
init _ =
    let
        initialSnake = List.map (\i -> { x = 5 - i, y = 5 }) (List.range 0 2) -- length 3
        initialDir = Right
        w = 15
        h = 15
        initialFood = { x = 7, y = 7 }
    in
    ( { snake = initialSnake
      , dir = initialDir
      , food = initialFood
      , width = w
      , height = h
      , gameOver = False
      , collisionWarningSteps = 0
      , highScore = 3
      , paused = False
      , viewportWidth = 360
      , viewportHeight = 640
      }
    , Browser.Dom.getViewport |> Task.perform (\vp -> GotViewport (round vp.viewport.width) (round vp.viewport.height))
    )

-- Msg

type Msg
    = Tick
    | ChangeDir Direction
    | Restart
    | NewFood Position
    | PauseResume
    | GotViewport Int Int
    | WindowResized Int Int

-- Timer

baseInterval : Float
baseInterval = 350

minInterval : Float
minInterval = 80

tickInterval : Int -> Float
tickInterval snakeLen =
    let
        speedup = toFloat (snakeLen - 3) * 12
        interval = baseInterval - speedup
    in
    max minInterval interval

tickCmd : Int -> Cmd Msg
tickCmd snakeLen =
    Process.sleep (tickInterval snakeLen)
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
            if model.paused then
                (model, tickCmd (List.length model.snake))
            else
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
                    newLength = List.length finalSnake
                    newHighScore = Basics.max model.highScore newLength
                    cmd =
                        if ateFood then
                            Random.generate NewFood (foodGenerator model.width model.height)
                        else
                            tickCmd newLength
                in
                ( { model | snake = finalSnake, gameOver = collided, collisionWarningSteps = warningSteps, highScore = newHighScore }
                , cmd
                )
        ChangeDir dir ->
            ( { model | dir = dir }, Cmd.none )
        Restart ->
            let
                (newModel, cmd) = init ()
            in
            ( { newModel | highScore = model.highScore }, cmd )
        NewFood pos ->
            ( { model | food = pos }, tickCmd (List.length model.snake) )
        PauseResume ->
            ( { model | paused = not model.paused }, Cmd.none )
        GotViewport w h ->
            let
                reservedSpace = 220
                boardPx = Basics.min w (h - reservedSpace)
                gridSize =
                    if boardPx < 320 then 12 else if boardPx < 480 then 15 else 20
            in
            ( { model | viewportWidth = w, viewportHeight = h, width = gridSize, height = gridSize }, Cmd.none )
        WindowResized w h ->
            let
                reservedSpace = 220
                boardPx = Basics.min w (h - reservedSpace)
                gridSize =
                    if boardPx < 320 then 12 else if boardPx < 480 then 15 else 20
            in
            ( { model | viewportWidth = w, viewportHeight = h, width = gridSize, height = gridSize }, Cmd.none )

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

type ButtonType = PauseBtn | ResetBtn | NavBtn Direction

buttonStyle : Model -> ButtonType -> List (Html.Attribute msg)
buttonStyle model btnType =
    let
        base =
            [ style "width" "220px"
            , style "height" "100px"
            , style "margin" "12px"
            , style "font-size" "3rem"
            , style "border" "2px solid #bbb"
            , style "border-radius" "20px"
            , style "box-shadow" "0 3px 8px #0001"
            , style "cursor" "pointer"
            , style "user-select" "none"
            , style "touch-action" "manipulation"
            , style "background" "#f5f5f5"
            , style "color" "#222"
            ]
    in
        case btnType of
            PauseBtn ->
                base ++
                    [ style "background" (if model.paused then "#FFC107" else "#4CAF50")
                    , style "color" "#fff"
                    ]
            ResetBtn ->
                base ++
                    [ style "background" "#2196F3"
                    , style "color" "#fff"
                    ]
            NavBtn dir ->
                base ++
                    [ style "background" (if model.dir == dir then "#2196F3" else "#f5f5f5")
                    , style "color" (if model.dir == dir then "#fff" else "#222")
                    ]

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
    Sub.batch
        [ Browser.Events.onKeyDown keyDecoder
        , Browser.Events.onResize (\w h -> WindowResized w h)
        ]

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
                    " " -> Decode.succeed PauseResume
                    _ -> Decode.fail "Not an arrow key or pause"
            )

-- Top-level function (already present):
cellSize : Model -> Int
cellSize model =
    let
        reservedSpace = 220
        boardPx = Basics.min model.viewportWidth (model.viewportHeight - reservedSpace)
    in
    boardPx // model.width

view : Model -> Html Msg
view model =
    let
        reservedSpace = 220
        boardPx = Basics.min model.viewportWidth (model.viewportHeight - reservedSpace)
        gridSize = model.width -- width == height
        cellSizeVal = boardPx // gridSize
        headPos =
            case model.snake of
                h :: _ -> Just h
                [] -> Nothing
        cellStyle isHead =
            [ style "width" (String.fromInt cellSizeVal ++ "px")
            , style "height" (String.fromInt cellSizeVal ++ "px")
            , style "display" "inline-block"
            , style "border" "1px solid #ccc"
            , style "box-sizing" "border-box"
            , style "border-radius" (if isHead then "4px" else "2px")
            ]
        titleStyle =
            [ style "font-size" "2.2rem"
            , style "font-weight" "bold"
            , style "margin-bottom" "18px"
            , style "font-family" "'Segoe UI', 'Roboto', 'Arial', sans-serif"
            , style "letter-spacing" ".5px"
            , style "color" "#222"
            , style "text-align" "center"
            ]
        boardContainerStyle =
            [ style "background" "#fff"
            , style "padding" "32px 32px 24px 32px"
            , style "border-radius" "12px"
            , style "box-shadow" "0 4px 24px #0002"
            , style "margin-top" "40px"
            , style "display" "inline-block"
            ]
        outerContainerStyle =
            [ style "display" "flex"
            , style "flex-direction" "column"
            , style "align-items" "center"
            , style "min-height" "100vh"
            , style "background" "#fafbfc"
            ]
        infoBoxStyle =
            [ style "background" "#f5f5f5"
            , style "border-radius" "6px"
            , style "box-shadow" "0 1px 3px #0001"
            , style "padding" "0.5rem 1rem"
            , style "width" "100%"
            , style "text-align" "center"
            , style "font-size" "1rem"
            ]

        infoStackStyle =
            [ style "width" "100%"
            , style "max-width" "600px"
            , style "margin" "2rem auto 0 auto"
            , style "display" "flex"
            , style "flex-direction" "column"
            , style "gap" "0.3rem"
            , style "align-items" "center"
            ]

        navGridStyle =
            [ style "display" "grid"
            , style "grid-template-columns" "repeat(3, 220px)"
            , style "grid-template-rows" "repeat(2, 100px)"
            , style "gap" "24px"
            , style "justify-content" "center"
            , style "margin" "0.5rem 0"
            ]

        navCellStyle =
            [ style "display" "flex", style "align-items" "center", style "justify-content" "center" ]
        pauseSymbol = if model.paused then "▶" else "⏸"
        resetSymbol = "⟲"

        containerStyle =
            [ style "min-height" "100vh"
            , style "width" "100vw"
            , style "display" "flex"
            , style "flex-direction" "column"
            , style "align-items" "center"
            , style "justify-content" "flex-start"
            , style "background" "#fff"
            , style "box-sizing" "border-box"
            , style "padding" "0.2rem"
            ]

        headerStyle =
            [ style "font-size" "2rem"
            , style "font-weight" "bold"
            , style "margin" "0.5rem 0 0.2rem 0"
            , style "text-align" "center"
            ]

        gameBoardStyle =
            [ style "width" (String.fromInt boardPx ++ "px")
            , style "height" (String.fromInt boardPx ++ "px")
            , style "background" "#fff"
            , style "border-radius" "10px"
            , style "box-shadow" "0 4px 24px #0002"
            , style "box-sizing" "border-box"
            , style "margin" "0 auto"
            ]

        controlsStyle =
            [ style "display" "flex"
            , style "flex-direction" "column"
            , style "align-items" "center"
            , style "margin" "5rem 0 0.2rem 0"
            , style "gap" "0.3rem"
            ]

        collisionButtonStyle =
            [ style "margin" "24px 0 0 0"
            , style "font-size" "18px"
            , style "padding" "10px 32px"
            , style "background" "#e53935"
            , style "color" "#fff"
            , style "border" "none"
            , style "border-radius" "6px"
            , style "box-shadow" "0 2px 8px #e5393533"
            , style "font-weight" "bold"
            , style "cursor" "not-allowed"
            ]
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
            div (cellStyle isHead ++ [style "background-color" bgColor]) []
        renderRow y =
            div [] (List.map (\x -> renderCell x y) (List.range 0 (gridSize - 1)))
        lengthAndCollision =
            let
                snakeLen = List.length model.snake
                speed = 1000 / (tickInterval snakeLen)
                speedStr = String.fromFloat (roundTo1 speed) ++ " moves/sec"
            in
            div infoStackStyle
                [ div infoBoxStyle [ text ("Snake length: " ++ String.fromInt snakeLen) ]
                , div infoBoxStyle [ text ("High score: " ++ String.fromInt model.highScore) ]
                , div infoBoxStyle [ text ("Speed: " ++ speedStr) ]
                ]
        pauseButtonStyle =
            [ style "margin" "24px 0 0 12px"
            , style "font-size" "18px"
            , style "padding" "10px 32px"
            , style "background" (if model.paused then "#FFC107" else "#4CAF50")
            , style "color" "#fff"
            , style "border" "none"
            , style "border-radius" "6px"
            , style "cursor" "pointer"
            , style "box-shadow" "0 2px 8px #0002"
            , style "transition" "background 0.2s"
            ]
        navButtonStyle dir =
            [ style "width" "72px"
            , style "height" "72px"
            , style "margin" "8px"
            , style "font-size" "2.5rem"
            , style "background" (if model.dir == dir then "#2196F3" else "#f5f5f5")
            , style "color" (if model.dir == dir then "#fff" else "#222")
            , style "border" "1.5px solid #bbb"
            , style "border-radius" "16px"
            , style "box-shadow" "0 2px 6px #0001"
            , style "cursor" "pointer"
            , style "user-select" "none"
            , style "touch-action" "manipulation"
            ]
    in
    div containerStyle
        [ div headerStyle [ text "Elm Snake Game" ]
        , div gameBoardStyle
            [ div [ style "user-select" "none" ] (List.map renderRow (List.range 0 (gridSize - 1))) ]
        , div controlsStyle
            [ div navGridStyle
                [ div (navCellStyle ++ [ style "grid-row" "1", style "grid-column" "1" ])
                    [ button (buttonStyle model PauseBtn ++ [onClick PauseResume]) [ text pauseSymbol ] ]
                , div (navCellStyle ++ [ style "grid-row" "1", style "grid-column" "2" ])
                    [ button (buttonStyle model (NavBtn Up) ++ [onClick (ChangeDir Up)]) [ text "↑" ] ]
                , div (navCellStyle ++ [ style "grid-row" "1", style "grid-column" "3" ])
                    [ button (buttonStyle model ResetBtn ++ [onClick Restart]) [ text resetSymbol ] ]
                , div (navCellStyle ++ [ style "grid-row" "2", style "grid-column" "1" ])
                    [ button (buttonStyle model (NavBtn Left) ++ [onClick (ChangeDir Left)]) [ text "←" ] ]
                , div (navCellStyle ++ [ style "grid-row" "2", style "grid-column" "2" ])
                    [ button (buttonStyle model (NavBtn Down) ++ [onClick (ChangeDir Down)]) [ text "↓" ] ]
                , div (navCellStyle ++ [ style "grid-row" "2", style "grid-column" "3" ])
                    [ button (buttonStyle model (NavBtn Right) ++ [onClick (ChangeDir Right)]) [ text "→" ] ]
                ]
            , if model.collisionWarningSteps > 0 then
                div [ style "display" "flex", style "justify-content" "center", style "margin-top" "8px" ]
                    [ button (collisionButtonStyle ++ [Html.Attributes.disabled True]) [ text "Collision!" ] ]
              else
                text ""
            ]
        , div infoStackStyle
            [ div infoBoxStyle [ text ("Snake length: " ++ String.fromInt (List.length model.snake)) ]
            , div infoBoxStyle [ text ("High score: " ++ String.fromInt model.highScore) ]
            , let speed = 1000 / (tickInterval (List.length model.snake)) in
                div infoBoxStyle [ text ("Speed: " ++ String.fromFloat (roundTo1 speed) ++ " moves/sec") ]
            ]
        ]

posToString : Position -> String
posToString pos =
    "(" ++ String.fromInt pos.x ++ "," ++ String.fromInt pos.y ++ ")"

roundTo1 : Float -> Float
roundTo1 n =
    (toFloat (round (n * 10))) / 10 