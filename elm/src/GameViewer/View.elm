module GameViewer.View exposing
    ( MoveNumbers
    , view
    , viewButtons
    , viewMoveList
    )

import Array
import Date
import FontAwesome.Icon as I
import FontAwesome.Solid as S
import Game exposing (..)
import GameViewer.Model exposing (..)
import GameViewer.Msg exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Loadable exposing (..)
import Popularities


view : Model -> Html Msg
view model =
    viewLoadable model.game (viewLoaded model) (text "")


viewLoaded : Model -> Game -> Html Msg
viewLoaded model game =
    let
        moves =
            game.moves

        players =
            game.properties.white
                ++ " ("
                ++ String.fromInt game.properties.whiteElo
                ++ ") - "
                ++ game.properties.black
                ++ " ("
                ++ String.fromInt game.properties.blackElo
                ++ ")"
    in
    div [ class "grid-x", class "grid-margin-x" ]
        [ div [ class "cell", class "medium-4" ]
            [ div [ class "grid-y", class "grid-margin-y" ]
                [ div [ class "cell" ]
                    [ h3 [] [ text players ]
                    , hr [] []
                    , text
                        (game.properties.site
                            ++ " "
                            ++ game.properties.event
                            ++ " "
                            ++ game.properties.round
                        )
                    , br [] []
                    , text
                        (Maybe.withDefault "" <|
                            Maybe.map Date.toIsoString game.properties.date
                        )
                    ]
                , div [ class "cell" ]
                    [ Html.map PopularitiesEvent
                        (Popularities.view model.popularities)
                    ]
                ]
            ]
        , div [ class "cell", class "medium-5" ]
            [ div [ class "grid-y", class "grid-margin-y" ]
                [ div [ class "cell" ]
                    [ div [ id "board-container", style "position" "relative" ]
                        [ div [ id "chessboard" ] [] ]

                    --, style "width" "400px" ] [] ]
                    , div [ class "text-right" ]
                        [ small []
                            [ em []
                                [ text "Use "
                                , kbd [] [ text "h" ]
                                , text " or "
                                , kbd [] [ text "l" ]
                                , text " to navigate with the keyboard."
                                ]
                            ]
                        ]
                    ]
                , div [ class "cell" ]
                    [ viewButtons
                        { moveNumber = model.move
                        , lastMoveNumber = Array.length moves - 1
                        }
                    ]
                ]
            ]
        , div [ class "cell", class "medium-3" ]
            [ viewMoveList
                (Array.toList moves)
                model.move
                game.properties.result
            ]
        ]



--------------------------------------------------------------------------------


viewMoveList : List Move -> Int -> Outcome -> Html Msg
viewMoveList moves currentMove outcome =
    div [ class "card" ]
        [ div [ class "grid-y", style "height" "600px" ]
            [ div
                [ class "cell"
                , class "medium-cell-block-y"
                , id "movelist-scroll"
                ]
                (List.indexedMap (viewMovePair currentMove) (pairwise moves)
                    ++ [ div [ class "grid-x" ]
                            [ div
                                [ class "cell"
                                , class "auto"
                                , class "medium-offset-1"
                                ]
                                [ text (outcomeToString outcome) ]
                            ]
                       ]
                )
            ]
        ]


viewMovePair : Int -> Int -> ( Move, Maybe Move ) -> Html Msg
viewMovePair currentMove rowId ( left, mright ) =
    let
        strRowId =
            String.fromInt rowId

        idDiv =
            div
                [ class "cell"
                , class "medium-2"
                , class "medium-offset-1"
                , id ("movelist-row-" ++ strRowId)
                ]
                [ text (String.fromInt (rowId + 1) ++ ".") ]

        wrapInDivs s =
            div [ class "grid-x" ] (idDiv :: s)

        stuff =
            case mright of
                Just right ->
                    [ div [ class "cell", class "medium-4" ]
                        [ viewMove left currentMove ]
                    , div [ class "cell", class "auto" ]
                        [ viewMove right currentMove ]
                    ]

                Nothing ->
                    [ div [ class "cell", class "medium-4" ]
                        [ viewMove left currentMove ]
                    ]
    in
    wrapInDivs stuff


viewMove : Move -> Int -> Html Msg
viewMove { san, fullMoveNumber, activeColour } currentMove =
    let
        thisMove =
            fullMoveNumber * 2 + activeColour - 3

        status =
            if thisMove < currentMove then
                "passed"

            else if thisMove == currentMove then
                "current"

            else
                "upcoming"
    in
    div [ class status, onClick (SetMoveNumberTo thisMove NoScroll) ]
        [ text san ]


pairwise : List a -> List ( a, Maybe a )
pairwise xs =
    case xs of
        [] ->
            []

        [ x ] ->
            [ ( x, Nothing ) ]

        x :: y :: zs ->
            ( x, Just y ) :: pairwise zs



--------------------------------------------------------------------------------


type alias MoveNumbers =
    { moveNumber : Int
    , lastMoveNumber : Int
    }


viewButtons : MoveNumbers -> Html Msg
viewButtons { moveNumber, lastMoveNumber } =
    let
        setter newMoveNumber =
            SetMoveNumberTo newMoveNumber Scroll
    in
    viewCenterCell <|
        div [ class "button-group" ]
            [ viewButton (setter -1) S.angleDoubleLeft
            , viewButton (setter (moveNumber - 1)) S.angleLeft
            , viewButton (setter (moveNumber + 1)) S.angleRight
            , viewButton (setter lastMoveNumber) S.angleDoubleRight
            ]


viewButton : msg -> I.Icon -> Html msg
viewButton msg icon =
    button [ class "button", onClick msg ] [ I.view icon ]


viewCenterCell : Html Msg -> Html Msg
viewCenterCell inner =
    div [ class "grid-x" ]
        [ div [ class "cell", class "auto" ] []
        , div [ class "cell", class "shrink" ] [ inner ]
        , div [ class "cell", class "auto" ] []
        ]
