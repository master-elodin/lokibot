require 'httparty'
require_relative 'cargos'
require_relative 'data'

class Transactions

  def initialize()
    @prices = {}
  end

  def buy_cargo(game_data, cargo_name, cargo_amt)
    if Data.is_cargo_banned(cargo_name, game_data['gameState']['planet'])
      puts "Tried to buy banned cargo `#{cargo_name}` on planet #{game_data['gameState']['planet']}"
      return
    end

    num_open_bays = game_data['gameState']['totalBays'] - game_data['gameState']['usedBays']
    cargo_price = game_data['currentMarket'][cargo_name]
    if cargo_amt == 'max'
      current_credits = game_data['gameState']['credits']

      cargo_amt = [(current_credits / cargo_price).floor, num_open_bays].min
    end

    if cargo_amt > num_open_bays
      puts "Tried to buy #{cargo_amt} but only have space for #{num_open_bays}"
      return
    end

    total_purchase_price = cargo_amt * cargo_price
    if total_purchase_price > game_data['gameState']['credits']
      puts "Tried to spend #{cargo_price} but only have #{game_data['gameState']['credits']}"
      return
    end

    unless Cargos.can_buy(cargo_name, cargo_price)
      puts "Not buying #{cargo_name} at #{cargo_price} because it is above buy price point of #{Cargos.get_price_point(cargo_name)[:buy]}"
      return
    end

    @prices[cargo_name] = cargo_price

    transaction_data = {side: 'buy'}
    transaction_data[cargo_name] = cargo_amt
    puts "Buying #{cargo_amt} #{cargo_name} at #{cargo_price} each, for a total cost of #{total_purchase_price}"

    market_response = HTTParty.post('https://skysmuggler.com/game/trade', body: {gameId: game_data['gameId'], transaction: transaction_data}.to_json)

    puts "market response for purchase: #{market_response}"
  end

  def sell_cargo(game_data)
    transaction_data = {side: 'sell'}
    game_data['gameState']['currentHold'].each do |cargo_name, value|
      cargo_price = game_data['currentMarket'][cargo_name]
      unless Data.is_cargo_banned(cargo_name, game_data['gameState']['planet']) or value == 0
        if Cargos.can_sell(cargo_name, cargo_price)
          transaction_data[cargo_name] = value
          puts "Selling #{cargo_name} at #{cargo_price} for a total income of #{cargo_price * value} credits"
        else
          puts "Not selling #{cargo_name} at #{cargo_price} because it is below the `sell` price point of #{Cargos.get_price_point(cargo_name)[:sell]}"
        end
      end
    end

    # size will be 1 if only `side: sell` exists
    if transaction_data.size == 1
      puts 'Nothing to sell'
      return
    end

    puts "selling cargo: #{transaction_data.to_json}"

    market_response = HTTParty.post('https://skysmuggler.com/game/trade', body: {gameId: game_data['gameId'], transaction: transaction_data}.to_json)

    puts "market response for sale: #{market_response}"
  end

end