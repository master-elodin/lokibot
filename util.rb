class Util

  def self.log(text)
    puts "#{self.add_commas(text)}"
  end

  def self.add_commas(text)
    text = text.to_s
    if text.index(/[a-zA-Z]+/).nil?
      # if no letters, just add commas to the number
      text.reverse.scan(/\d{3}|.+/).join(",").reverse.gsub(/-,/, '-')
    else
      # if given text is a string, add commas to each number
      text.gsub(/\d+/) {|n| self.add_commas(n)}
    end
  end
end