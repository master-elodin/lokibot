class Cargos

  @sell_percentage = 1.2
  @buy_percentage = 0.7
  @prices = {}

  def self.sell_percentage
    @sell_percentage
  end

  def self.buy_percentage
    @buy_percentage
  end

  def self.cargo_names
    %w[mining medical narcotics weapons water metal]
  end

  def self.price_points
    if @prices.length == 0
      puts 'Initializing cargo prices...'

      puts "pre-set sell percentage = #{@sell_percentage}"
      puts "pre-set buy percentage = #{@buy_percentage}"

      # find the average buy and sell adjustments for all the better-than-average games
      successful_cargo_decisions = [{:sell_percentage => @sell_percentage, :buy_percentage => @buy_percentage}]
      DATABASE.get_db[:cargo_decisions].where(:above_avg_score => true).order(:final_score).each do |row|
        successful_cargo_decisions << row
      end
      # only take the top 10 scores
      successful_cargo_decisions = successful_cargo_decisions[0..[10, successful_cargo_decisions.length].min]

      if successful_cargo_decisions.length > 0
        sell = 0
        buy = 0
        successful_cargo_decisions.each do |decision|
          sell += decision[:sell_percentage]
          buy += decision[:buy_percentage]
        end
        @sell_percentage = (sell / (successful_cargo_decisions.length * 1.0)).round(2)
        @buy_percentage = (buy / (successful_cargo_decisions.length * 1.0)).round(2)
      end

      puts "sell percentage = #{@sell_percentage}"
      puts "buy percentage = #{@buy_percentage}"
      @sell_percentage = 1.01
      @buy_percentage = 0.99

      DATABASE.get_db[:transaction_meta].all.each do |meta|
        avg_price = meta[:avg_price]
        # adjust prices based on average price for the given cargo all the times it's been seen
        @prices[meta[:name]] = {:sell => (avg_price * @sell_percentage).round(0), :buy => (avg_price * @buy_percentage).round(0)}
        puts "#{meta[:name]} = #{@prices[meta[:name]]}"
      end
    end
    @prices
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

  def self.price_differential(cargo_name, buy_price)
    self.price_points[cargo_name][:sell] - buy_price
  end

  def self.get_probable_profit(cargo_name)
    (self.price_points[cargo_name][:sell] + self.price_points[cargo_name][:buy]) / 2
  end

  def self.possible_cargo_value(game, planet_name)
    possible_value = 0
    game.game_state['currentHold'].each do |cargo_name, cargo_amt|
      # don't count value of cargo if it's banned on the potential planet
      unless Data.is_cargo_banned(cargo_name, planet_name)
        possible_value += cargo_amt * Cargos.price_differential(cargo_name, Cargos.get_price_point(cargo_name)[:buy])
      end
    end
    possible_value
  end

end