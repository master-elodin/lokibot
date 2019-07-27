class Cargos

  def self.price_points
    {
        'mining' => {:sell => 1800, :buy => 1400},
        'medical' => {:sell => 2600, :buy => 2000},
        'narcotics' => {:sell => 35000, :buy => 25000},
        'weapons' => {:sell => 71000, :buy => 60000},
        'water' => {:sell => 17000, :buy => 15000},
        'metal' => {:sell => 700, :buy => 500}
    }
  end

  def self.get_price_point(cargo_name)
    self.price_points[cargo_name]
  end

  def self.can_buy(cargo_name, current_market_price)
    current_market_price <= self.price_points[cargo_name][:buy]
  end

  def self.can_sell(cargo_name, current_market_price)
    current_market_price >= self.price_points[cargo_name][:sell]
  end

  def self.price_differential(cargo_name, buy_price = self.price_points[cargo_name][:buy], sell_price = self.price_points[cargo_name][:sell])
    sell_price - buy_price
  end
end