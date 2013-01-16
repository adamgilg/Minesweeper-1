require 'yaml'

class Minesweeper
  def initialize
  #AG: interesting way of structuring your initialize
    load_game? ? load_game : setup_board
  end

  def play
    until won?
      print_board
      guess = get_guess

      case type = guess.shift
      when 'r'
        break if is_bomb?(guess)
        reveal(guess)
      when 'f'
        set_flag(guess)
      when 'save'
        save_game
        exit
      end
    end

    if won?
      puts "You won!"
    else
      print_board(true)
      puts
      puts "Boom. You lose!"
    end
  end

  private
  ### Setup methods
  def setup_board
    print "How many rows/cols would you like the board to have? "
    size = gets.chomp.to_i
    #AG: Nice! Allowing for any board size. I like it.
    @board = create_board(size)
    populate_bombs((size * size) / 7)
  end

  def create_board(size)
    Array.new(size) do
      Array.new(size) do
        { flagged: false, revealed: false, bomb: false }
      end
    end
  end

  def populate_bombs(num)
    bombs = []
    until bombs.length == num
      pos = [rand(@board.length), rand(@board.length)]
      bombs << pos unless bombs.include?(pos)
    end
#AG: We were considering an array of arrays (for bombs), but Ned suggested using a separate board position class
#AG: that stores all your info. This ended up working our really well.
    bombs.each { |(x,y)| @board[x][y][:bomb] = true }
  end

  ### Save/Load Methods
  def load_game?
    print "Do you want to load a game (y/n)? "
    case gets.chomp.downcase
    when 'y'
      true
    else
      false
    end
  end

  def load_game
    print "What's the name of the file? "
    @board = load_file(gets.chomp.downcase)
  end

  def load_file(name)
    YAML.load_file("#{name}.yml")
  end

  def save_game
    print "What would you like to call your game? "
    name = gets.chomp
    puts "Load from '#{name}' to continue. Bye!"
    save_file(name)
  end

  def save_file(name)
    File.open("#{name}.yml", 'w') do |f|
      f.puts @board.to_yaml
    end
  end
#AG: We definitely had too many classes, but I think you could benefit from breaking this into separate
#AG: classes such as Board (above) and Game (or something) - as it stands your class is very long.
  ### Play Methods
  def get_guess
    guess = [@board.length + 10, @board.length + 10]
    while true
      print "Enter your move in this format : 'r/f row col' (ex: 'r 3 4'): "
      #AG: Split will split on whitespace by default - don't need the (' ')
      input = gets.chomp.downcase.split(' ')
      type = input[0]
      break if type == 'save'
      #AG: Your get_guess method is doing a lot more than just getting the guess. Perhaps consider
      #AG: a get_guess and process_guess or something (although you do have a separate valid_guess?)
      guess = [input[1].to_i - 1, input[2].to_i - 1]
      if valid_guess?(guess) && type.match(/^[rf]/)
        break
      else
        puts "Invalid guess. Please guess again."
      end
    end

    [type] + guess
  end

  def set_flag(pos)
    x, y = pos
    @board[x][y][:flagged] = true
  end

  def reveal(pos)
    x, y = pos
    @board[x][y][:revealed] = true
    @board[x][y][:flagged] = false
    if adjacent_bomb_count(pos) == 0
      find_neighbors(pos).each do |neighbor|
        x, y = neighbor
        reveal(neighbor) unless @board[x][y][:revealed]
      end
    end
  end
#AG: I like all these short and single-purpose methods.
  def adjacent_bomb_count(pos)
    count = 0
    find_neighbors(pos).each { |neighbor| count += 1 if is_bomb?(neighbor) }
    count
  end

  def find_neighbors(pos)
    x, y = pos
    #AG: We did this by iterating through our neighbors (or ADJACENTS) and adding these to their row and column
    #AG: A few more lines of code, but I think it ended up being a little more readable.
    neighbors = [ [x - 1, y + 1], [x, y + 1], [x + 1, y + 1],
                  [x - 1, y], [x + 1, y],
                  [x - 1, y - 1], [x, y - 1], [x + 1, y - 1] ]

    max = @board.length - 1
    neighbors.select { |neighbor| in_board?(neighbor) }
  end

  def valid_guess?(guess)
    in_board?(guess) && unrevealed?(guess)
  end

  def in_board?(pos)
    max = @board.length - 1
    (0..max).include?(pos[0]) && (0..max).include?(pos[1])
  end

  def unrevealed?(pos)
    x, y = pos
    @board[x][y][:revealed] == false
  end

  def won?
    @board.each do |row|
      row.each { |pos| return false if pos[:flagged] != pos[:bomb] }
    end
    true
  end

  def is_bomb?(pos)
    x, y = pos
    @board[x][y][:bomb]
  end

  ### Print Methods
  def print_board(lost = false)
    print_header

    @board.each_with_index do |row, x|
      print_row_headers(x)
      row.each_with_index do |pos, y|
        mark = (lost ? get_losing_mark(pos, x, y) : get_mark(pos, x, y))
        print "#{mark}  "
      end
    end

    print_column_headers
  end

  def print_header
    puts
    print " *"
    print "MINESWEEPER".center(@board.length * 3, '*')
    puts
    print "   (type 'save' to save game)".center(@board.length * 3, ' ')
    puts
    print " ".ljust((@board.length * 3) + 2, '-')
  end

  def print_row_headers(row)
    if (row + 1).to_s.length == 1
      print "\n 0#{row + 1} "
    else
      print "\n #{row + 1} "
    end
  end

  def print_column_headers
    puts
    print "   "
    (1..@board.length).to_a.each do |x|
      if x.to_s.length == 1
        print "0#{x} "
      else
        print "#{x} "
      end
    end
    puts "\n\n"
  end

  def get_mark(square, x, y)
    mark = if square[:flagged]
      'F'
    elsif square[:revealed]
      adjacent_bomb_count([x, y])
    else
      '*'
    end
  end

  def get_losing_mark(square, x, y)
    mark = if square[:bomb]
      '$'
    elsif square[:revealed]
      adjacent_bomb_count([x, y])
    else
      '*'
    end
  end

  ### Debugging methods
  # def print_debug_board
  #   @board.each_with_index do |row, x|
  #     print "\n #{x + 1} "
  #     row.each_with_index do |pos, y|
  #       mark = if pos[:bomb]
  #         'B'
  #       else
  #         '*'
  #       end

  #       print "#{mark} "
  #     end
  #   end

  #   puts
  #   print "   #{(1..@board.length).to_a.join(" ")}"
  #   puts "\n\n"
  # end
end

Minesweeper.new.play
