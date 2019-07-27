require 'httparty'
require_relative 'transactions'
require_relative 'travel'

TURN_CUTOFF = 12

def create_new_game
  game_data = HTTParty.get('https://skysmuggler.com/game/new_game').parsed_response
  puts "Game ID: #{game_data['gameId']}"
  game_data
end

def take_turn(game_data, game_transactions = Transactions.new, travel = Travel.new)
  # --- sell
  game_transactions.sell_cargo(game_data)

  # --- buy
  game_transactions.buy_cargo(game_data)

  # TODO: loanshark
  # TODO: shipyard
  # TODO: bank

  # --- travel
  game_data = travel.travel(game_data)

  # handle notifications
  unless game_data['notifications'].nil? or game_data['notifications'].length == 0
    puts "notifications: #{game_data['notifications']}"
  end

  turns_left = game_data['gameState']['turnsLeft']
  current_credits = game_data['gameState']['credits']
  puts "At the end of turn ##{20 - turns_left}, you have #{current_credits} credits"
  puts "Game data: #{game_data}"
  puts

  if turns_left > TURN_CUTOFF
    take_turn(game_data, game_transactions, travel)
  else
    puts "You made #{current_credits - 20000} credits this game"
    puts "You traveled to these planets: #{travel.get_planets_traveled_to}"
    puts "You made these transactions:"
    game_transactions.print_history
  end
end

starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
take_turn(create_new_game)
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "Completed game in #{((ending - starting) * 1000).round(3)} milliseconds"
