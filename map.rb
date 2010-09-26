class Map
  ENEMY = {:S => {:health => 24, :damage => 3},
           :a => {:health => 7, :damage => 3}}
  DIRECTIONS = [:forward, :backward]

  def initialize(player, warrior)
    @player = player
    @warrior = warrior
    @current_enemy = nil
    @safe_locations = []
    @previous_location = nil
    @current_current_enemy_location = nil
    @enemy_location_to_info = {}

    # A matrix of X columns by Y rows
    @map = {}
  end
  attr_accessor :current_current_enemy_location, :previous_location

  def update!(warrior)
    @warrior = warrior
    register_current_enemy!
    current_x, current_y = current_location_of_warrior
    @map[current_x] ||= {}
    @map[current_x][current_y] = '@'.to_sym
    @map[current_x][current_y+1] = pretty_space(@warrior.feel(:forward))
    @map[current_x][current_y-1] = pretty_space(@warrior.feel(:backward))

    if @player.just_started_taking_damage?
      # Find a spot that's 2 away and is unknown
    end
  end

  # What about walls?
  def pretty_space(space)
    space.empty? ? nil : space.unit.character.to_sym
  end

  # Get number of squares between warrior and given location
  def get_distance_away(location)
    target_x, target_y = location
    current_x, current_y = currnet_location
    distance = (((target_x - current_x).to_f ** 2) + ((target_y - current_y).to_f ** 2)) ** 0.5
    distance = distance.ceil
    distance - 1
  end

  def opposite_direction_of(dir)
    case dir
    when :forward then :backward
    when :backward then :forward
    end
  end

  # Returns a direction that will bring the warrior closer to the given location.
  def towards(location)
    target_x, target_y = location
    current_x, current_y = current_location_of_warrior
    current_x > target_x ? :backward : :forward
  end

  # Returns a direction that will bring the warrior farther away from the given location.
  def away_from(location)
    opposite_direction_of(towards(location))
  end

  # Mark the current location as safe
  def mark_safe_location!(location)
    @safe_locations << location unless @safe_locations.include?(location)
  end

  # Is a given location safe?
  def is_safe_location?(location)
    @safe_locations.include?(location)
  end

  def current_location_of_warrior
    backward = @warrior.feel(:backward).location
    x_coord = backward[0] + 1
    y_coord = backward[1]
    [x_coord, y_coord]
  end

  # Return a direction towards closest safe space
  def towards_safe_space
    puts "Moving toward safe space"
    if @player.taking_damage_from_afar? and @player.should_rest?
      # Move away from threat
      direction = away_from(location_of_current_enemy)
    else
      direction = opposite_direction_of(@player.direction)
    end
    direction
  end

  def towards_current_enemy
    towards(location_of_current_enemy)
  end

  # ENEMY TRACKING
  def current_enemy
    new_enemy = nil
    if @player.taking_damage_from_afar?
      new_enemy = :a
    elsif @player.next_to_enemy?
      dir = DIRECTIONS.detect { |d| @warrior.feel(d).enemy? }
      new_enemy = @warrior.feel(dir).character
    end
    # Update only if we have a new enemy
    if new_enemy
      @current_enemy = new_enemy
    end
    @current_enemy = @current_enemy.to_sym unless @current_enemy.nil?
    @current_enemy
  end

  # Returns a Hash of info about most recent enemy. Hash is empty if
  # no enemies have been encountered yet.
  def get_current_enemy_info
    return {} if current_enemy.nil?
    info = {}
    info[:location] = location_of_current_enemy
    info[:direction] = towards(info[:location])
    info[:character] = current_enemy
    info.merge!(ENEMY[info[:character]])

    info
  end

  # Register the most recent enemy. We need to keep track of their health!
  def register_current_enemy!
    return if current_enemy.nil?
    info = get_current_enemy_info
    @enemy_location_to_info[info[:location]] ||= info
  end

  # Returns location of closest enemy. May be nil.
  def location_of_current_enemy
    if @player.next_to_enemy?
      dir = DIRECTIONS.detect{|d| @warrior.feel(d).enemy? }
      @current_enemy_location = @warrior.feel(dir).location
    elsif current_enemy == :a and @player.just_started_taking_damage?
      x,y = current_location_of_warrior
      # Archer is shooting at us. They have a range of 2 squares.
      # i.e. |@  a| is sufficient for them to hit the warrior.
      @current_enemy_location = [x+3, y]
    end
    @current_enemy_location
  end

  # Removes most recent enemy from @enemy_location_to_info hash
  def unregister_current_enemy!
    info = get_current_enemy_info
    @enemy_location_to_info.delete(info[:location])
    @just_killed_an_enemy = true
  end

  # Decrement most recent enemy's health, unregistering them if they died.
  def decrement_current_enemys_health_by(amount)
    info = get_current_enemy_info
    @enemy_location_to_info[info[:location]][:health] -= amount
    if @enemy_location_to_info[info[:location]][:health] <= 0
      # Enemy died
      unregister_current_enemy!
    end
  end

  # Get info about a specific enemy
  def get_info_about_enemy_at(location)
    @enemy_location_to_info[location]
  end
end
