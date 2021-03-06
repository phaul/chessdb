require 'roda'

require_relative 'lib/application'

class App < Roda
  app = Application.new

  plugin :assets,
    css: ['application.scss', 'svg-with-js.min.css'],
    js: ['application.js', 'chessboard.js', 'jquery-min.js'],
    dependencies: app.dependency_map,
    postprocessor: Application.method(:post_process_asset)
  plugin :public
  opts[:root] = Configuration::PROJECT_ROOT
  plugin :static ['/public']
  plugin :json
  plugin :json_parser, parser: -> str { JSON.parse(str, symbolize_names: true) }
  plugin :halt
  plugin :environments
  compile_assets if production?

  route do |r|
    r.assets
    r.public

    r.root do
      r.redirect 'games/search'
    end

    r.get 'about' do
      @active_menu = :about
      app.erb_store.resolve_html(:about, binding)
    end

    r.on 'games' do
      r.get Integer do |id|
        @active_menu = :none
        fullmove_number = Integer(r.params.fetch('fullmove_number', 1))
        active_colour = Integer(r.params.fetch('active_colour', 0))
        @halfmove_number = fullmove_number * 2 + active_colour - 3
        app.erb_store.resolve_html(:game_viewer, binding)
      end

      r.get(/(\d+).json/) do |id|
        app.repository
          .game(id: id)
          .merge(moves: app.repository.moves_in_game(game_id: id).all)
      end

      r.get 'search' do
        @active_menu = :search
        app.erb_store.resolve_html(:game_search, binding)
      end

      r.post 'search' do
        {
          count: app.repository.game_count(r.params),
          offset: r.params.dig(:pagination, :offset) || 0,
          data: app.repository.game_search(r.params)
        }
      end
    end

    r.on 'moves' do
      r.get 'explorer' do
        begin
          @fen = r.params.fetch('fen_position',
                               'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR')
          @castling_availability = 
            Integer(r.params.fetch('castling_availability', 15))
          @active_colour = Integer(r.params.fetch('active_colour', 0))
          @en_passant = r.params['en_passant']&.yield_self do |i|
            Integer(i)
          end
        rescue ArgumentError
          halt 400
        end

        @active_menu = :explorer
        app.erb_store.resolve_html(:move_explorer, binding)
      end

      r.get 'popularities.json' do
        begin
          token = Integer(r.params.fetch('token', 0))
          fen = r.params['fen_position']
          castle = Integer(r.params.fetch('castling_availability', 0))
          active_colour = Integer(r.params.fetch('active_colour', 0))
          en_passant = r.params['en_passant']&.yield_self do |i|
            Integer(i)
          end
        rescue ArgumentError
          halt 400
        end

        # needs to be consistent across processes
        hash = [fen, castle, active_colour, en_passant].to_s

        data = app.cache.fetch(hash) do
          app.repository.popular_moves(fen: fen,
                                       castle: castle,
                                       active_colour: active_colour,
                                       en_passant: en_passant).all
        end

        { token: token, moves: data }
      end
    end

    r.on 'positions' do
      r.get 'search' do
        @active_menu = :position_search
        app.erb_store.resolve_html(:position_search, binding)
      end

      r.post 'search' do
        {
          count: app.repository.position_count(r.params),
          offset: r.params.dig(:pagination, :offset) || 0,
          data: app.repository.position_search(r.params)
        }
      end
    end
  end
end

run App.freeze.app
