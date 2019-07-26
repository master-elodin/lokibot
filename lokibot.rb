require 'httparty'
require_relative 'transactions'
require_relative 'travel'

TURN_CUTOFF = 15

def create_new_game
  game_data = HTTParty.get('https://skysmuggler.com/game/new_game').parsed_response
  puts "Game ID: #{game_data['gameId']}"
  game_data
end

def take_turn(game_data, game_transactions = Transactions.new, travel = Travel.new)
  # --- sell
  game_transactions.sell_cargo(game_data)

  # --- buy
  game_transactions.buy_cargo(game_data, 'metal', 'max')

  # TODO: loanshark
  # TODO: shipyard
  # TODO: bank

  # --- travel
  game_data = travel.travel(game_data)

  current_credits = game_data['gameState']['credits']
  puts "At the end of turn, you have #{current_credits} credits"
  puts "Game data: #{game_data}"
  puts

  if game_data['gameState']['turnsLeft'] > TURN_CUTOFF
    take_turn(game_data, game_transactions, travel)
  else
    puts "You made #{current_credits - 20000} credits this game"
    puts "You traveled to these planets: #{travel.get_planets_traveled_to}"
  end
end

starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
take_turn(create_new_game)
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "Completed game in #{((ending - starting) * 1000).round(3)} milliseconds"
