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

# summarize all the data from all the games
def update_market_meta
  puts 'Updating market meta...'
  starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  new_meta = {}
  DATABASE.get_db[:market_avg].all.each do |row|
    cargo_name = row[:name]
    if new_meta[cargo_name].nil?
      new_meta[cargo_name] = {:total_price => 0, :total_num_times_seen => 0, :num_averages => 0}
    end
    new_meta[cargo_name][:total_price] += row[:price]
    new_meta[cargo_name][:total_num_times_seen] += row[:num_times_seen]
    new_meta[cargo_name][:num_averages] += 1
  end
  new_meta.each do |cargo_name, value|
    DATABASE.get_db[:transaction_meta].where(:name => cargo_name).delete
    DATABASE.get_db[:transaction_meta]
        .insert(:name => cargo_name,
                :avg_price => value[:total_price] / value[:num_averages],
                :avg_price_purchased => 0,
                :avg_price_sold => 0,
                :num_times_seen => value[:total_num_times_seen],
                :num_times_purchased => 0,
                :num_times_sold => 0)
  end

  ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  puts "Finished updating market meta in #{((ending - starting) * 1000).round(3)} milliseconds"
  puts
end

def summarize_market(game_id)
  market_combined_prices = {}
  DATABASE.get_db[:market]
      .where(:game_id => game_id)
      .map([:name, :price]).each do |name, price|
    if market_combined_prices[name].nil?
      market_combined_prices[name] = {:combined_price => 0, :num_times_seen => 1}
    end
    market_combined_prices[name][:combined_price] += price
    market_combined_prices[name][:num_times_seen] += 1
  end
  market_combined_prices.each do |name, value|
    avg_price = value[:combined_price] / value[:num_times_seen]
    DATABASE.get_db[:market_avg].insert(:game_id => game_id,
                                        :name => name,
                                        :price => avg_price,
                                        :num_times_seen => value[:num_times_seen])
  end

  update_market_meta
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

  # --- add market data for current planet
  current_planet = game_data['gameState']['planet']
  turn_number = 20 - game_data['gameState']['turnsLeft']
  game_data['currentMarket'].each do |cargo_name, cargo_price|
    unless cargo_price.nil?
      DATABASE.get_db[:market].insert(:game_id => game_id,
                                      :planet => current_planet,
                                      :name => cargo_name,
                                      :price => cargo_price,
                                      :turn_number => turn_number)
    end
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
  if current_credits == 0
    sellable_cargo_value = game_transactions.get_sellable_cargo_value(game_data)
    forced_repayment_recovered = sellable_cargo_value >= MIN_CREDITS_AFTER_REPAYMENT
    if not forced_repayment_recovered
      game_over = true
      puts 'Putting you out of your misery - you have no credits left and not enough cargo to be worth selling'
    elsif turns_left > 1
      puts "You have 0 credits, but you have #{sellable_cargo_value} credits worth of cargo that can be sold"
      take_turn(game_data, game_transactions, travel)
    end
    DATABASE.update_forced_repayment(game_id, true, forced_repayment_recovered)
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
      else
        puts 'Submitting scores is turned off'
        puts
      end

    end
  end

  if game_over
    # summarize market data for the whole game
    summarize_market(game_id)

    DATABASE.add_final_score(game_id, current_credits)
    game_transactions.get_transactions.each do |transaction|
      DATABASE.add_transaction(game_id, transaction[:planet], transaction[:type], transaction[:name],
                               transaction[:amount], transaction[:price], transaction[:turn_number])
    end

    puts "You traveled to these planets: #{travel.get_planets_traveled_to}"
    puts "You made these transactions:"
    transactions_for_game = DATABASE.get_transaction_list(game_id)
    transactions_for_game.each do |transaction|
      puts transaction.to_json
    end
    puts "You made #{current_credits - 20000} credits this game"

    puts
    puts "All-time stats"
    puts "Average total score: #{DATABASE.get_average_final_score}"
    puts "Percent games with loanshark forced repayment: #{DATABASE.get_percent_forced_repayment}%"
    puts "Percent games with loanshark forced repayment recovered: #{DATABASE.get_percent_forced_repayment_recovered}%"
  end
end

starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
take_turn(create_new_game)
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "Completed game in #{((ending - starting) * 1000).round(3)} milliseconds"
