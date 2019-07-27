require 'httparty'
require_relative 'transactions'
require_relative 'travel'

LOAN_SHARK_PLANET = 'umbriel'
MIN_CREDITS_AFTER_REPAYMENT = 10000
SCORE_NAME = 'Loki'

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

  # TODO: quit if no credits left because loan shark took them and no cargo left either
  if current_credits == 0
    puts 'Putting you out of your misery - you have no credits left'
    return
  end

  if turns_left > 1
    take_turn(game_data, game_transactions, travel)
  else
    score_response = HTTParty.post('https://skysmuggler.com/scores/submit', body: {gameId: game_data['gameId'], name: 'joe rebel'}.to_json)

    puts "Score response: #{score_response}"
    if score_response['message'] == 'New high score!'
      HTTParty.post('https://skysmuggler.com/scores/update_name', body: {gameId: game_data['gameId'], newName: SCORE_NAME}.to_json)
    else
      puts "Not a high score"
    end
    # https://skysmuggler.com/scores/submit
    # {"gameId":"0ddf371e-1085-4767-aeb0-7d008572315a","name":"joe rebel"}
    #
    # success
    # {"message":"New high score!","scoreTypes":["weekly"],"status":"success"}
    #
    # failure
    # {"message":"Sorry, not a high score!","scoreTypes":[],"status":"success"}
    #
    # https://skysmuggler.com/scores/update_name
    # {"gameId":"0ddf371e-1085-4767-aeb0-7d008572315a","newName":"Tim"}
    #
    # https://skysmuggler.com/scores/list?length=10&scoreType[]=allTime&scoreType[]=weekly

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
