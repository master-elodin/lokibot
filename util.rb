class Util

  LOG_ALL = false
  @log_statements = []

  def self.print
    @log_statements.each(&method(:puts))
  end

  def self.log_to_file(file_name)
    File.open(file_name, 'w') do |file|
      @log_statements.each do |log|
        file.puts log
      end
    end
  end

  def self.clear
    @log_statements = []
  end

  def self.add_newline
    self.log('')
  end

  def self.log(text, do_log = LOG_ALL)
    log = self.add_commas(text)
    @log_statements << log
    if do_log
      puts log
    end
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