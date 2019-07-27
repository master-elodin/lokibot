require 'httparty'
require_relative 'transactions'
require_relative 'travel'

LOAN_SHARK_PLANET = 'umbriel'
MIN_CREDITS_AFTER_REPAYMENT = 10000
SCORE_NAME = 'Loki'

SHOULD_SUBMIT_SCORE = false

DATABASE = DatabaseConnector.new

def create_new_game
  game_data = HTTParty.get('https://skysmuggler.com/game/new_game').parsed_response
  puts "Game ID: #{game_data['gameId']}"
  game_data
end

def take_turn(game_data, game_transactions = Transactions.new, travel = Travel.new)

  game_id = game_data['gameId']

  game_state = game_data['gameState']
  credits_after_repayment = game_state['credits'] - game_state['loanBalance']
  if game_state['loanBalance'] > 0 and game_state['planet'] == LOAN_SHARK_PLANET and credits_after_repayment > MIN_CREDITS_AFTER_REPAYMENT
    puts "Repaying loan of #{game_state['loanBalance']}, leaving balance of #{credits_after_repayment}"
    game_data = HTTParty.post('https://skysmuggler.com/game/loanshark',
                              body: {gameId: game_id, transaction: {qty: game_state['loanBalance'], side: "repay"}}.to_json)
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

  turns_left = game_data['gameState']['turnsLeft']
  current_credits = game_data['gameState']['credits']
  puts "At the end of turn ##{20 - turns_left}, you have #{current_credits} credits"
  puts "Game data: #{game_data}"
  puts

  game_over = false
  # TODO: quit if no credits left because loan shark took them and no cargo left either
  if current_credits == 0
    game_over = true
    puts 'Putting you out of your misery - you have no credits left'
    DATABASE.update_forced_repayment(game_id, true)
  else
    if turns_left > 1
      take_turn(game_data, game_transactions, travel)
    else
      game_over = true
      DATABASE.update_forced_repayment(game_id, false)

      if SHOULD_SUBMIT_SCORE
        score_response = HTTParty.post('https://skysmuggler.com/scores/submit', body: {gameId: game_data['gameId'], name: 'joe rebel'}.to_json)

        puts "Score response: #{score_response}"
        if score_response['message'] == 'New high score!'
          HTTParty.post('https://skysmuggler.com/scores/update_name', body: {gameId: game_data['gameId'], newName: SCORE_NAME}.to_json)
        else
          puts "Not a high score"
        end
        # https://skysmuggler.com/scores/list?length=10&scoreType[]=allTime&scoreType[]=weekly
      else
        puts 'Submitting scores is turned off'
      end

    end
  end

  if game_over
    DATABASE.add_final_score(game_id, current_credits)

    puts "You made #{current_credits - 20000} credits this game"
    puts "You traveled to these planets: #{travel.get_planets_traveled_to}"
    puts "You made these transactions:"
    game_transactions.print_history

    puts
    puts "All-time stats"
    puts "Average total score: #{DATABASE.get_average_final_score}"
    puts "Percent games with loanshark forced repayment: #{DATABASE.get_percent_forced_repayment}%"
  end
end

starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
take_turn(create_new_game)
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "Completed game in #{((ending - starting) * 1000).round(3)} milliseconds"
