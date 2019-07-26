require 'httparty'
require_relative 'data'
require_relative 'transactions'
require_relative 'travel'

def create_new_game
  HTTParty.get('https://skysmuggler.com/game/new_game').parsed_response
end

def get_turns_left(game_data)
  game_data['gameState']['turnsLeft']
end

def take_turn(game_id, game_data, game_transactions)
  if get_turns_left(game_data) > 0
    market_response = game_transactions.buy_cargo(game_id, 'metal', 3)
    puts "market response: #{market_response}"
    # next_planet = Travel.choose_next_planet(game_data['gameState']['planet'])
    # Travel.travel(game_id, next_planet)
  end
end

original_game_data = create_new_game
game_transactions = Transactions.new
game_data = original_game_data

game_id = game_data['gameId']
puts "Game ID: #{game_id}"

take_turn(game_id, game_data, game_transactions)
