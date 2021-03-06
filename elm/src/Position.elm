module Position exposing
    ( Position, initial, empty, specific
    , make, canCastle, setCastle
    , jsonEncode, urlEncode, fen
    )

{-| A board along with the castling availabilities, side to move, en passant

#Types and constructors

Creating positions with empty boards, initial board set up or with specific fen
strings is possible.

@docs Position, initial, empty, specific

#Data manipulation

Note that make also takes care of castling rights, the `canCastle`, `setCastle`
functions are simply helpers.

@docs make, canCastle, setCastle

#Conversions

@docs jsonEncode, urlEncode, fen

-}

import Bitwise as Bit
import Board
    exposing
        ( Board
        , Castle(..)
        , Disambiguity(..)
        , Kind(..)
        , Move(..)
        , Piece(..)
        )
import Board.Colour as Colour exposing (Colour(..))
import Board.Scanner as Scanner
import Board.Square as Square exposing (File(..), Rank(..), Square(..))
import Json.Encode
import Maybe.Extra as Maybe
import Parser
import State
import Url.Builder as Url



------------------------------------------------------------------------
--                       Types and constructors                       --
------------------------------------------------------------------------


type alias Position =
    { board : Board
    , castlingAvailability : Int
    , activeColour : Colour
    , enPassant : Maybe Square
    }


{-| starting position
-}
initial : Position
initial =
    { board = Board.initial
    , castlingAvailability = 15
    , activeColour = White
    , enPassant = Nothing
    }


{-| Invalid position with an empty board
-}
empty : Position
empty =
    { board = Board.empty
    , castlingAvailability = 15
    , activeColour = White
    , enPassant = Nothing
    }


{-| A specific position from a fen, castling, etc
This might fail if things don't parse correctly.
-}
specific : String -> Int -> Int -> Maybe Int -> Result String Position
specific fenPosition castlingAvailability activeColour mEnPassant =
    let
        board =
            Parser.run Board.boardParser fenPosition
                |> Result.mapError Parser.deadEndsToString

        colour =
            Colour.fromEncoded activeColour

        enPassant =
            case Maybe.map Square.fromEncoded mEnPassant of
                Just (Ok sq) ->
                    Ok (Just sq)

                Just (Err oops) ->
                    Err oops

                Nothing ->
                    Ok Nothing
    in
    Result.map3
        (\b c ep ->
            { board = b
            , castlingAvailability = castlingAvailability
            , activeColour = c
            , enPassant = ep
            }
        )
        board
        colour
        enPassant



------------------------------------------------------------------------
--                         Data manipulation                          --
------------------------------------------------------------------------


{-| Makes a move on a position.
-}
make : Move -> Position -> Result String Position
make moveE position =
    let
        rSource =
            sourceSquare moveE position

        newBoard =
            pieces moveE position

        newCastle =
            castles moveE position.castlingAvailability

        newEnPassant =
            updateEnPassant moveE position.activeColour
    in
    rSource
        |> Result.map
            (\source ->
                { position
                    | board = newBoard source
                    , castlingAvailability = newCastle source
                    , enPassant = newEnPassant source
                    , activeColour = Colour.flip position.activeColour
                }
            )


canCastle : Colour -> Castle -> Position -> Bool
canCastle colour castle position =
    let
        msk =
            castleMask colour castle
    in
    Bit.and msk position.castlingAvailability == msk


setCastle : Position -> Colour -> Castle -> Bool -> Position
setCastle position colour castle bool =
    let
        msk =
            castleMask colour castle
    in
    if bool then
        { position
            | castlingAvailability = Bit.or position.castlingAvailability msk
        }

    else
        { position
            | castlingAvailability =
                Bit.and position.castlingAvailability (Bit.complement msk)
        }



------------------------------------------------------------------------
--                            Conversions                             --
------------------------------------------------------------------------


urlEncode : Position -> List Url.QueryParameter
urlEncode { board, castlingAvailability, activeColour, enPassant } =
    Maybe.values
        [ Just (Url.string "fen_position" (Board.toFen board))
        , Just (Url.int "castling_availability" castlingAvailability)
        , Just (Colour.toUrlQueryParameter "active_colour" activeColour)
        , enPassant |> Maybe.map (Square.toUrlQueryParameter "en_passant")
        ]


jsonEncode : Position -> Json.Encode.Value
jsonEncode { board, castlingAvailability, activeColour, enPassant } =
    Json.Encode.object <|
        Maybe.values
            [ Just ( "fen_position", Json.Encode.string (Board.toFen board) )
            , Just
                ( "castling_availability"
                , Json.Encode.int castlingAvailability
                )
            , Just ( "active_colour", Colour.jsonEncode activeColour )
            , enPassant
                |> Maybe.map (\ep -> ( "en_passant", Square.jsonEncode ep ))
            ]


fen : Position -> String
fen position =
    Board.toFen position.board



------------------------------------------------------------------------
--                              Private                               --
------------------------------------------------------------------------


castleMask : Colour -> Castle -> Int
castleMask colour castle =
    case ( colour, castle ) of
        ( White, Short ) ->
            1

        ( White, Long ) ->
            2

        ( Black, Short ) ->
            4

        ( Black, Long ) ->
            8


pieces : Move -> Position -> Square -> Board
pieces moveE position source =
    case ( position.activeColour, moveE ) of
        ( White, Castle Short ) ->
            position.board
                |> Board.putPiece Square.g1 (Just (Piece White King))
                |> Board.putPiece Square.f1 (Just (Piece White Rook))
                |> Board.putPiece Square.e1 Nothing
                |> Board.putPiece Square.h1 Nothing

        ( White, Castle Long ) ->
            position.board
                |> Board.putPiece Square.c1 (Just (Piece White King))
                |> Board.putPiece Square.d1 (Just (Piece White Rook))
                |> Board.putPiece Square.e1 Nothing
                |> Board.putPiece Square.a1 Nothing

        ( Black, Castle Short ) ->
            position.board
                |> Board.putPiece Square.g8 (Just (Piece Black King))
                |> Board.putPiece Square.f8 (Just (Piece Black Rook))
                |> Board.putPiece Square.e8 Nothing
                |> Board.putPiece Square.h8 Nothing

        ( Black, Castle Long ) ->
            position.board
                |> Board.putPiece Square.c8 (Just (Piece Black King))
                |> Board.putPiece Square.d8 (Just (Piece Black Rook))
                |> Board.putPiece Square.e8 Nothing
                |> Board.putPiece Square.a8 Nothing

        ( _, Normal move ) ->
            normalMovePieces move position source


normalMovePieces move position source =
    let
        movedPiece =
            Piece position.activeColour <|
                Maybe.withDefault move.kind move.promotion

        normal =
            position.board
                |> Board.putPiece move.destination (Just movedPiece)
                |> Board.putPiece source Nothing

        remove =
            Square.square
                (Square.file move.destination)
                (Square.rank source)
    in
    case ( move.kind, move.capture, position.enPassant ) of
        ( Pawn, true, Just enPassantSquare ) ->
            if enPassantSquare == move.destination then
                normal
                    |> Board.putPiece remove Nothing

            else
                normal

        _ ->
            normal


sourceSquare : Move -> Position -> Result String Square
sourceSquare moveE position =
    case moveE of
        Castle _ ->
            case position.activeColour of
                White ->
                    Ok Square.e1

                Black ->
                    Ok Square.e8

        Normal move ->
            let
                piece =
                    Board.Piece position.activeColour move.kind

                condition b ix =
                    case move.disambiguity of
                        Just (FileDisambiguity fd) ->
                            Board.get ix b == Just piece && Square.file ix == fd

                        Just (RankDisambiguity rd) ->
                            Board.get ix b == Just piece && Square.rank ix == rd

                        Nothing ->
                            Board.get ix b == Just piece

                scan scanner =
                    Scanner.run
                        (scanner position.board condition move.destination)
            in
            case move.kind of
                Knight ->
                    scan Scanner.knight
                        |> Result.fromMaybe "Knight not found"

                Bishop ->
                    scan Scanner.bishop
                        |> Result.fromMaybe "Bishop not found"

                Queen ->
                    scan Scanner.queen
                        |> Result.fromMaybe "Queen not found"

                Rook ->
                    scan Scanner.rook
                        |> Result.fromMaybe "Rook not found"

                King ->
                    scan Scanner.king
                        |> Result.fromMaybe "King not found"

                Pawn ->
                    scan (Scanner.pawn position.activeColour move.capture)
                        |> Result.fromMaybe "Pawn not found"


castles : Move -> Int -> Square -> Int
castles moveE castling source =
    let
        destination =
            case moveE of
                -- doesn't matter what, the source of the move will set no
                -- castling to the side
                Castle _ ->
                    Square.e4

                Normal move ->
                    move.destination

        a1Mask =
            if source == Square.a1 || destination == Square.a1 then
                2

            else
                0

        e1Mask =
            if source == Square.e1 then
                3

            else
                0

        h1Mask =
            if source == Square.h1 || destination == Square.h1 then
                1

            else
                0

        a8Mask =
            if source == Square.a8 || destination == Square.a8 then
                8

            else
                0

        e8Mask =
            if source == Square.e8 then
                12

            else
                0

        h8Mask =
            if source == Square.h8 || destination == Square.h8 then
                4

            else
                0

        mask =
            Bit.or a1Mask e1Mask
                |> Bit.or h1Mask
                |> Bit.or a8Mask
                |> Bit.or e8Mask
                |> Bit.or h8Mask
    in
    Bit.and (Bit.complement mask) castling


updateEnPassant : Move -> Colour -> Square -> Maybe Square
updateEnPassant moveE colour source =
    case moveE of
        Castle _ ->
            Nothing

        Normal move ->
            case
                ( ( colour, move.kind )
                , Square.rank source
                , Square.rank move.destination
                )
            of
                ( ( White, Pawn ), Rank 2, Rank 4 ) ->
                    Square.offsetBy 8 move.destination

                ( ( Black, Pawn ), Rank 7, Rank 5 ) ->
                    Square.offsetBy -8 move.destination

                _ ->
                    Nothing
