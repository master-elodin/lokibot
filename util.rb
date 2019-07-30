class Util

  def self.add_commas(number)
    number.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse.gsub(/-,/, '-')
  end
end