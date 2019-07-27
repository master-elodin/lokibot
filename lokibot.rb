require 'httparty'
require_relative 'transactions'
require_relative 'travel'

TURN_CUTOFF = 5

LOAN_SHARK_PLANET = 'umbriel'
MIN_CREDITS_AFTER_REPAYMENT = 10000

def create_new_game
  game_data = HTTParty.get('https://skysmuggler.com/game/new_game').parsed_response
  puts "Game ID: #{game_data['gameId']}"
  game_data
end

def take_turn(game_data, game_transactions = Transactions.new, travel = Travel.new)

  game_state = game_data['gameState']
  credits_after_repayment = game_state['credits'] - game_state['loanBalance']
  if game_state['loanBalance'] > 0 and game_state['planet'] == LOAN_SHARK_PLANET and credits_after_repayment > MIN_CREDITS_AFTER_REPAYMENT
    puts "Repaying loan of #{game_state['loanBalance']}, leaving balance of #{credits_after_repayment}"
    game_data = HTTParty.post('https://skysmuggler.com/game/loanshark',
                              body: {gameId: game_data['gameId'], transaction: {qty: game_state['loanBalance'], side: "repay"}}.to_json)
  end

  # --- sell
  game_data = game_transactions.sell_cargo(game_data)

  # --- buy
  game_data = game_transactions.buy_cargo(game_data)

  # TODO: bank

  # --- travel
  game_data = travel.travel(game_data)

  # handle notifications
  unless game_data['notifications'].nil? or game_data['notifications'].length == 0
    puts "notifications: #{game_data['notifications']}"
  end

  turns_left = game_state['turnsLeft']
  current_credits = game_state['credits']
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
