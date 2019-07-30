require 'httparty'
require_relative 'data'
require_relative 'game'

SCORE_NAME = 'Loki'
SHOULD_SUBMIT_SCORE = false

DATABASE = DatabaseConnector.new

# summarize all the data from all the games
def update_market_meta
  puts 'Updating market meta...'
  starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  new_meta = {}

  # get market averages for each game
  DATABASE.get_db[:market_avg].all.each do |row|
    cargo_name = row[:name]
    if new_meta[cargo_name].nil?
      new_meta[cargo_name] = {:total_price => 0,
                              :total_num_times_seen => 0,
                              :num_averages => 0,
                              :total_price_purchased => 0,
                              :total_amt_purchased => 0,
                              :total_num_times_purchased => 0,
                              :total_price_sold => 0,
                              :total_amt_sold => 0,
                              :total_num_times_sold => 0}
    end
    new_meta[cargo_name][:total_price] += row[:price]
    new_meta[cargo_name][:total_num_times_seen] += row[:num_times_seen]
    new_meta[cargo_name][:num_averages] += 1
  end

  # TODO: don't query all transactions every time (low priority since it only takes 24ms anyway)
  # get average transaction data (checks ALL transactions right now)
  DATABASE.get_db[:transaction].all.each do |row|
    cargo_name = row[:name]
    cargo_meta = new_meta[cargo_name]

    if row[:type] == 'purchase'
      # -- purchase
      cargo_meta[:total_price_purchased] += row[:price]
      cargo_meta[:total_amt_purchased] += row[:amount]
      cargo_meta[:total_num_times_purchased] += 1
    else
      # -- sale
      cargo_meta[:total_price_sold] += row[:price]
      cargo_meta[:total_amt_sold] += row[:amount]
      cargo_meta[:total_num_times_sold] += 1
    end

  end

  # update transaction meta (data averaging for every game)
  new_meta.each do |cargo_name, value|
    DATABASE.get_db[:transaction_meta].where(:name => cargo_name).delete
    DATABASE.get_db[:transaction_meta]
        .insert(:name => cargo_name,
                :avg_price => value[:total_price] / value[:num_averages],
                :num_times_seen => value[:total_num_times_seen],
                # purchase
                :total_amt_purchased => value[:total_amt_purchased],
                :num_times_purchased => value[:total_num_times_purchased],
                :avg_price_purchased => value[:total_price_purchased] / value[:total_num_times_purchased],
                :avg_amt_purchased => value[:total_amt_purchased] / value[:total_num_times_purchased],
                # sale
                :total_amt_sold => value[:total_amt_sold],
                :num_times_sold => value[:total_num_times_sold],
                :avg_price_sold => value[:total_price_sold] / value[:total_num_times_sold],
                :avg_amt_sold => value[:total_amt_sold] / value[:total_num_times_sold])
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

def add_final_score(game)
  cargo_names = []
  cargo_count = 0
  game.market.current_hold.each do |name, numOnBoard|
    cargo_count += numOnBoard
    if numOnBoard > 0
      cargo_names << name
    end
  end

  DATABASE.get_db[:score].insert(:game_id => game.id,
                                 :final_score => game.current_credits,
                                 :unsold_cargo => cargo_count > 0,
                                 :unsold_cargo_name => cargo_names.to_json,
                                 :final_planet => game.current_planet,
                                 :total_bays => game.total_bays)
end

def submit_score(game)
  if SHOULD_SUBMIT_SCORE
    score_response = HTTParty.post('https://skysmuggler.com/scores/submit', body: {gameId: game.id, name: 'joe rebel'}.to_json)

    puts "Score response: #{score_response}"
    if score_response['message'] == 'New high score!'
      HTTParty.post('https://skysmuggler.com/scores/update_name', body: {gameId: game.id, newName: SCORE_NAME}.to_json)
    else
      puts "Not a high score"
    end
  else
    puts 'Submitting scores is turned off'
    puts
  end
end

def take_turn(game = Game.new(DATABASE))

  game.market.record_current_market

  loan_amt_start_turn = game.loan_balance

  game.market.sell_cargo

  game.repay_loanshark
  game.shipyard.buy_bays

  # TODO: borrow from loanshark if low price event with high profit chance
  # TODO: don't buy medical if maybe traveling to taspra
  game.market.buy_cargo

  # TODO: bank

  game.travel

  puts "At the end of turn ##{game.current_turn}, you have #{game.current_credits} credits"
  puts

  game_over = false
  if game.loan_shark_attacked
    puts 'Attacked by loan shark'
    sellable_cargo_value = game.market.get_sellable_cargo_value
    forced_repayment_recoverable = sellable_cargo_value >= MIN_CREDITS_AFTER_REPAYMENT
    if not forced_repayment_recoverable
      game_over = true
      puts 'Putting you out of your misery - you have no credits left and not enough cargo to be worth selling'
    elsif game.turns_left > 1
      puts "You have 0 credits, but you have #{sellable_cargo_value} credits worth of cargo that can be sold"
      take_turn(game)
    end

    # don't add another loanshark entry if there's already one for the game
    unless DATABASE.get_db[:loanshark].where(:game_id => game.id).count > 0
      DATABASE.get_db[:loanshark].insert(:game_id => game.id,
                                         :forced_repayment => true,
                                         :forced_repayment_recovered => forced_repayment_recoverable,
                                         :loan_amt_repaid => loan_amt_start_turn,
                                         :sellable_cargo_value_at_repayment => sellable_cargo_value,
                                         :turn_repaid => game.current_turn)
    end
  else
    if game.turns_left > 1
      take_turn(game)
    else
      # sell everything on board
      game.market.sell_cargo

      game_over = true
      submit_score(game)
    end
  end

  if game_over
    # summarize market data for the whole game
    summarize_market(game.id)

    add_final_score(game)

    puts "You made these transactions:"
    transactions_for_game = DATABASE.get_transaction_list(game.id)
    transactions_for_game.each do |transaction|
      puts transaction.to_json
    end
    puts "You made #{game.current_credits - 20000} credits this game"

    puts
    puts "All-time stats"
    puts "Average total score: #{DATABASE.get_average_final_score}"
    puts "Percent games with loanshark forced repayment: #{DATABASE.get_percent_forced_repayment}%"
    puts "Percent games with loanshark forced repayment recovered: #{DATABASE.get_percent_forced_repayment_recovered}%"
  end
end

starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
take_turn
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "Completed game in #{((ending - starting) * 1000).round(3)} milliseconds"
