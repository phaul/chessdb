module GameSearch.Model exposing
    ( Error
    , Model
    , datePickerSettings
    , hasEitherOrOpponent
    , hasWhiteOrBlack
    , init
    , isModelValid
    , jsonEncodedQuery
    , sendQuery
    , updateModel
    , validateModel
    )

import Date exposing (Date)
import DatePicker exposing (DatePicker)
import Game exposing (GameProperties, Outcome(..))
import GameSearch.Msg as Msg exposing (FieldChange(..), Msg(..))
import Http
import Json.Encode as Encode exposing (Value)
import Loadable exposing (Loadable(..))
import Pagination exposing (Pagination)
import Url.Builder as Url


type alias Error =
    Maybe String


type alias Model =
    { white : String
    , black : String
    , eitherColour : String
    , opponent : String
    , elosDontMatch : Error
    , minimumElo : Maybe Int
    , maximumElo : Maybe Int
    , event : String
    , site : String
    , date : Maybe Date
    , datePicker : DatePicker
    , round : String
    , result : String
    , ecoInvalid : Error
    , eco : String
    , pagination : Pagination
    , games : Loadable (List GameProperties)
    }


datePickerSettings : DatePicker.Settings
datePickerSettings =
    let
        default =
            DatePicker.defaultSettings
    in
    { default | dateFormatter = Date.format "yyyy-MM-dd" }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        ( datePicker, datePickerCmd ) =
            DatePicker.init

        model =
            { white = ""
            , black = ""
            , eitherColour = ""
            , opponent = ""
            , elosDontMatch = Nothing
            , minimumElo = Nothing
            , maximumElo = Nothing
            , event = ""
            , site = ""
            , date = Nothing
            , datePicker = datePicker
            , round = ""
            , result = ""
            , ecoInvalid = Nothing
            , eco = ""
            , pagination = Pagination.init
            , games = Loading
            }
    in
    ( model
    , Cmd.batch
        [ Cmd.map SetDatePicker datePickerCmd
        , sendQuery model
        ]
    )


sendQuery : Model -> Cmd Msg
sendQuery model =
    Http.post
        { url = Url.absolute [ "games", "search" ] []
        , body = Http.jsonBody (jsonEncodedQuery model)
        , expect = Http.expectJson GamesReceived Msg.jsonResponseDecoder
        }


validateModel : Model -> Model
validateModel model =
    let
        compareElos =
            Maybe.map2 (<=) model.minimumElo model.maximumElo

        elosDontMatch =
            case compareElos of
                Just False ->
                    Just "Minimum ELO can't be larger than maximum elo"

                _ ->
                    Nothing

        ecoInvalid =
            case String.toList model.eco of
                [ a, b, c ] ->
                    if 'A' <= a && a <= 'E' && '0' <= b && b <= '9' && '0' <= c && c <= '9' then
                        Nothing

                    else
                        Just "Invalid ECO code."

                [] ->
                    Nothing

                _ ->
                    Just "Invalid ECO code."
    in
    { model
        | elosDontMatch = elosDontMatch
        , ecoInvalid = ecoInvalid
    }


isModelValid : Model -> Bool
isModelValid model =
    model.elosDontMatch == Nothing && model.ecoInvalid == Nothing


hasWhiteOrBlack : Model -> Bool
hasWhiteOrBlack model =
    model.white /= "" || model.black /= ""


hasEitherOrOpponent : Model -> Bool
hasEitherOrOpponent model =
    model.eitherColour /= "" || model.opponent /= ""


updateModel : FieldChange -> Model -> Model
updateModel msg model =
    case msg of
        WhiteChanged str ->
            { model | white = str }

        BlackChanged str ->
            { model | black = str }

        EitherColourChanged str ->
            { model | eitherColour = str }

        OpponentChanged str ->
            { model | opponent = str }

        MinimumEloChanged str ->
            { model | minimumElo = String.toInt str }

        MaxiumEloChanged str ->
            { model | maximumElo = String.toInt str }

        EventChanged str ->
            { model | event = str }

        SiteChanged str ->
            { model | site = str }

        RoundChanged str ->
            { model | round = str }

        ResultChanged str ->
            { model | result = str }

        EcoChanged str ->
            { model | eco = str }


jsonEncodedQuery : Model -> Encode.Value
jsonEncodedQuery model =
    let
        stringQuery ( name, str ) =
            case str of
                "" ->
                    Nothing

                _ ->
                    Just ( name, Encode.string str )

        numberQuery ( name, mint ) =
            mint |> Maybe.map (\int -> ( name, Encode.int int ))

        dateQuery ( name, mdate ) =
            mdate
                |> Maybe.map
                    (\date -> ( name, Encode.string (Date.toIsoString date) ))
    in
    Encode.object
        (List.filterMap stringQuery
            [ ( "white", model.white )
            , ( "black", model.black )
            , ( "either_colour", model.eitherColour )
            , ( "opponent", model.opponent )
            , ( "event", model.event )
            , ( "site", model.site )
            , ( "round", model.round )
            , ( "eco", model.eco )
            , ( "result", model.result )
            ]
            ++ List.filterMap numberQuery
                [ ( "minimum_elo", model.minimumElo )
                , ( "maximum_elo", model.maximumElo )
                ]
            ++ List.filterMap dateQuery [ ( "date", model.date ) ]
            ++ [ ( "offset", Encode.int model.pagination.offset ) ]
        )
