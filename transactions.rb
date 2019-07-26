class Transactions

  @prices = {}

  def self.get_last_purchase_price(cargo_name)
    @prices[cargo_name]
  end

  def self.set_last_purchase_price(cargo_name, price)
    @prices[cargo_name] = price
  end

  def buy_cargo(game_id, cargo_name, cargo_amt)
    # TODO: validate cost
    # TODO: validate cargo space
    # TODO: set last purchase price
    HTTParty.post('https://skysmuggler.com/game/trade',
                  body: { gameId: game_id,
                          transaction: get_transaction_data('buy', cargo_name, cargo_amt)
                  }.to_json)
  end

  def get_transaction_data(side, cargo_name, cargo_amount)
    transaction_data = {side: side}
    Data.all_cargo.each {|cargo|
      if cargo == cargo_name
        transaction_data[cargo] = cargo_amount
      else
        transaction_data[cargo] = 0
      end
    }
    transaction_data
  end

end