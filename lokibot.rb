require 'httparty'
require_relative 'transactions'
require_relative 'travel'

def create_new_game
  game_data = HTTParty.get('https://skysmuggler.com/game/new_game').parsed_response
  puts "Game ID: #{game_data['gameId']}"
  game_data
end

def take_turn(game_data, game_transactions)
  if game_data['gameState']['turnsLeft'] > 10
    game_id = game_data['gameId']

    market_response = game_transactions.sell_cargo(game_data)
    puts "market response for sale: #{market_response}"

    market_response = game_transactions.buy_cargo(game_data, 'metal', 'max')
    puts "market response for purchase: #{market_response}"

    next_planet = Travel.choose_next_planet(game_data)
    game_data = Travel.travel(game_id, next_planet)

    puts "At the end of turn, you have #{game_data['gameState']['credits']} credits"
    puts

    take_turn(game_data, game_transactions)
  end
end

starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
take_turn(create_new_game, Transactions.new)
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "Completed game in #{((ending - starting) * 1000).round(3)} milliseconds"
