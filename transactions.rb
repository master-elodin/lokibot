require 'httparty'
require_relative 'data'

class Transactions

  @prices = {}

  def self.get_last_purchase_price(cargo_name)
    @prices[cargo_name]
  end

  def self.set_last_purchase_price(cargo_name, price)
    @prices[cargo_name] = price
  end

  def buy_cargo(game_data, cargo_name, cargo_amt)
    if Data.is_cargo_banned(cargo_name, game_data['gameState']['planet'])
      return
    end

    if cargo_amt == 'max'
      cargo_price = game_data['currentMarket'][cargo_name]
      current_credits = game_data['gameState']['credits']

      cargo_amt = [(current_credits / cargo_price).floor, game_data['gameState']['totalBays']].min
    end
    # TODO: validate cost
    # TODO: validate cargo space
    # TODO: set last purchase price

    transaction_data = {side: 'buy'}
    transaction_data[cargo_name] = cargo_amt
    puts "purchasing cargo: #{transaction_data.to_json}"

    HTTParty.post('https://skysmuggler.com/game/trade',
                  body: {gameId: game_data['gameId'],
                         transaction: transaction_data
                  }.to_json)
  end

  def sell_cargo(game_data)
    transaction_data = {side: 'sell'}
    game_data['gameState']['currentHold'].each do |key, value|
      unless Data.is_cargo_banned(key, game_data['gameState']['planet']) or value == 0
        transaction_data[key] = value
      end
    end

    puts "selling cargo: #{transaction_data.to_json}"

    HTTParty.post('https://skysmuggler.com/game/trade',
                  body: {gameId: game_data['gameId'],
                         transaction: transaction_data
                  }.to_json)
  end

end