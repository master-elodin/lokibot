require 'httparty'
require_relative 'cargos'
require_relative 'data'

class Transactions

  def initialize()
    @prices = {}
    @transactions = []
  end

  def buy_cargo(game_data)
    # don't over-buy
    if game_data['gameState']['totalBays'] - game_data['gameState']['usedBays'] == 0
      puts "No space to buy cargo"
      return game_data
    end

    possible_cargos = []
    current_credits = game_data['gameState']['credits']
    game_data['currentMarket'].each do |cargo_name, cargo_price|
      unless cargo_price.nil?
        is_not_banned = !Data.is_cargo_banned(cargo_name, game_data['gameState']['planet'])
        is_within_price_point = Cargos.can_buy(cargo_name, cargo_price)
        can_afford = cargo_price <= current_credits

        if is_not_banned and is_within_price_point and can_afford
          possible_cargos << {:cargo_name => cargo_name, :cargo_price => cargo_price}
        end
      end
    end

    # sort by price differential to get the best potential value
    possible_cargos.sort {|a, b| Cargos.price_differential(b[:cargo_name]) <=> Cargos.price_differential(a[:cargo_name])}
    puts "Possible cargo: #{possible_cargos}"

    credits_left = current_credits
    num_open_bays = game_data['gameState']['totalBays'] - game_data['gameState']['usedBays']
    possible_cargos.each do |cargo|
      puts "#{credits_left} credits left"
      if credits_left >= cargo[:cargo_price] and num_open_bays > 0
        puts "Going to purchase #{cargo[:cargo_name]}..."
        game_data = buy_single_cargo(game_data, cargo[:cargo_name], 'max')
        if game_data.nil?
          puts "Didn't receive response for cargo"
          break
        else
          credits_left = game_data['gameState']['credits']
          num_open_bays = game_data['gameState']['totalBays'] - game_data['gameState']['usedBays']
        end
      else
        break
      end
    end
    game_data
  end

  def buy_single_cargo(game_data, cargo_name, cargo_amt)
    if Data.is_cargo_banned(cargo_name, game_data['gameState']['planet'])
      puts "Tried to buy banned cargo `#{cargo_name}` on planet #{game_data['gameState']['planet']}"
      return game_data
    end

    num_open_bays = game_data['gameState']['totalBays'] - game_data['gameState']['usedBays']
    cargo_price = game_data['currentMarket'][cargo_name]
    if cargo_amt == 'max'
      current_credits = game_data['gameState']['credits']

      cargo_amt = [(current_credits / cargo_price).floor, num_open_bays].min
    end

    if cargo_amt > num_open_bays
      puts "Tried to buy #{cargo_amt} but only have space for #{num_open_bays}"
      return game_data
    end

    total_purchase_price = cargo_amt * cargo_price
    if total_purchase_price > game_data['gameState']['credits']
      puts "Tried to spend #{cargo_price} but only have #{game_data['gameState']['credits']}"
      return game_data
    end

    unless Cargos.can_buy(cargo_name, cargo_price)
      puts "Not buying #{cargo_name} at #{cargo_price} because it is above buy price point of #{Cargos.get_price_point(cargo_name)[:buy]}"
      return game_data
    end

    unless cargo_amt > 0
      puts "Nothing to buy"
      return game_data
    end

    @prices[cargo_name] = cargo_price
    @transactions << {:type => 'purchase', :name => cargo_name, :price => cargo_price, :amount => cargo_amt}

    transaction_data = {side: 'buy'}
    transaction_data[cargo_name] = cargo_amt
    puts "Buying #{cargo_amt} #{cargo_name} at #{cargo_price} each, for a total cost of #{total_purchase_price}"

    market_response = HTTParty.post('https://skysmuggler.com/game/trade', body: {gameId: game_data['gameId'], transaction: transaction_data}.to_json)

    puts "Market response for purchase: #{market_response}"
    market_response
  end

  def sell_cargo(game_data)
    # TODO: sell cargo if lower price differential if possible to buy higher differential if there was space

    transaction_data = {side: 'sell'}
    game_data['gameState']['currentHold'].each do |cargo_name, value|
      cargo_price = game_data['currentMarket'][cargo_name]
      if value > 0 and Data.is_cargo_banned(cargo_name, game_data['gameState']['planet'])
        puts "Cannot sell `#{cargo_name}` on #{game_data['gameState']['planet']}"
      elsif value > 0
        if Cargos.can_sell(cargo_name, cargo_price)
          transaction_data[cargo_name] = value
          puts "Selling #{value} #{cargo_name} at #{cargo_price} for a total income of #{cargo_price * value} credits"
          @transactions << {:type => 'sale', :name => cargo_name, :price => cargo_price, :amount => value}
        else
          puts "Not selling #{cargo_name} at #{cargo_price} because it is below the `sell` price point of #{Cargos.get_price_point(cargo_name)[:sell]}"
        end
      end
    end

    # size will be 1 if only `side: sell` exists
    if transaction_data.size == 1
      puts 'Nothing to sell'
      return game_data
    end

    market_response = HTTParty.post('https://skysmuggler.com/game/trade', body: {gameId: game_data['gameId'], transaction: transaction_data}.to_json)

    puts "Market response for sale: #{market_response}"
    market_response
  end

  def print_history
    @transactions.each do |transaction|
      puts transaction.to_json
    end
  end

end