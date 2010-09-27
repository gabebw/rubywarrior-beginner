class Map
  ENEMIES = {:S => {:health => 24, :damage => 3},
           :a => {:health => 7, :damage => 3}}
  DIRECTIONS = [:forward, :backward]
  ARCHER_RANGE = 3

  def initialize(player, warrior)
    @player = player
    @warrior = warrior
    @current_enemy_character = nil
    @unsafe_locations = []
    @previous_location = nil
    #@current_enemy_location = nil
    @enemy_location_to_info = {}
    @just_killed_an_enemy = false

    # A matrix of X columns by Y rows
    @map = {}
  end
  attr_accessor :current_current_enemy_location,
                :previous_location,
                :just_killed_an_enemy

  def update!(warrior)
    @warrior = warrior # yes, have to reset each time
    # Add player
    update_location(current_location_of_warrior, '@'.to_sym)
    DIRECTIONS.each do |dir|
      space = @warrior.feel(dir)
      update_location(space.location, pretty_space(space))
    end

    if @player.taking_damage_from_afar? and @player.just_started_taking_damage? and
      @player.previous_direction != nil # is nil if called :rest previously, which has no direction
      delta = case @player.previous_direction
              when :forward then ARCHER_RANGE
              when :backward then ARCHER_RANGE * -1
              end
      # Warrior is being attacked by an archer
      current_x, current_y = current_location_of_warrior
      update_location([current_x+delta, current_y], :a)
    end
  end

  # Update the location with the given character. If the character is an
  # enemy, then also mark spaces that the enemy can attack.
  def update_location(location, character)
    x, y = location
    @map[x] ||= {}
    @map[x][y] = character
    if ENEMIES.key?(character)
      register_enemy_at!(location, character)
      enemy_influence(location, character).each do |loc|
        mark_unsafe_location!(loc)
      end
    end
  end

  # Returns an array of locations like [[x,y], [x1,y1]] that correspond to
  # the locations that a given enemy can attack.
  def enemy_influence(location, character)
    return [] unless ENEMIES.key?(character)
    orig_x, orig_y = location
    # Add location and spots immediately to its left and right
    influence = [location]
    influence << [orig_x + 1, orig_y]
    influence << [orig_x - 1, orig_y]
    if character == :a
      # Mark locations inside archer's range as unsafe
      (1..ARCHER_RANGE).to_a.each do |squares_away|
        # Archers can shoot backwards and forward
        influence << [orig_x + squares_away, orig_y]
        influence << [orig_x - squares_away, orig_y]
      end
    end
    influence
  end

  def pretty_space(space)
    if space.stairs?
      :<
    elsif space.wall?
      :|
    else
      space.empty? ? nil : space.unit.character.to_sym
    end
  end

  # Get number of squares between warrior and given location
  def get_distance_away(location)
    target_x, target_y = location
    current_x, current_y = current_location_of_warrior
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

  # Mark a given location as unsafe
  def mark_unsafe_location!(location)
    unless @unsafe_locations.include?(location) or # no duplicates
      location[0] < 0 or location[1] < 0 # [0,0] is minimum
      @unsafe_locations << location
    end
  end

  # Mark a given location as safe. Since locations default to safe, this
  # removes them from @unsafe_locations.
  def mark_safe_location!(location)
    @unsafe_locations.delete(location)
  end

  # Is a given location safe?
  def is_safe_location?(location)
    not @unsafe_locations.include?(location)
  end

  def current_location_of_warrior
    @player.current_location
  end

  # Return a direction towards closest safe space
  def towards_safe_space
    puts "Moving toward safe space"
    return towards(location_of_closest_safe_space)

    if @player.taking_damage? and @player.should_rest?
      # Move away from threat
      direction = away_from(location_of_closest_enemy)
    else
      direction = opposite_direction_of(@player.direction)
    end
    direction
  end

  def towards_current_enemy
    #towards(location_of_current_enemy)
    towards(location_of_closest_enemy)
  end

  # ENEMIES TRACKING
  def current_enemy_character
    new_enemy = nil
    if @player.taking_damage_from_afar?
      # Only archers have range attack
      new_enemy = :a
    elsif @player.next_to_enemy?
      # If we're next to the enemy, then feel which enemy it is
      dir = DIRECTIONS.detect { |d| @warrior.feel(d).enemy? }
      new_enemy = @warrior.feel(dir).character
    end
    # Update only if we have a new enemy
    if new_enemy
      @current_enemy_character = new_enemy.to_sym
    end
    #@current_enemy_character = @current_enemy_character.to_sym unless @current_enemy_character.nil?
    @current_enemy_character
  end

  # Returns a Hash of info about most recent enemy. Hash is empty if
  # no enemies have been encountered yet.
  # Hash keys:
  #  * :location
  #  * :character
  #  * :damage (how much damage enemy does per turn)
  #  * :health
  def create_enemy_info_hash(location, character)
    return {} if character.nil?
    info = {}
    info[:location] = location
    info[:character] = character.to_sym
    info.merge!(ENEMIES[info[:character]])
    info
  end

  # Register the most recent enemy. We need to keep track of their health!
  def register_enemy_at!(location, character = nil)
    # Don't re-register enemies
    return if @enemy_location_to_info.key?(location)

    character ||= current_enemy_character
    info = create_enemy_info_hash(location, character)
    @enemy_location_to_info[location] = info
  end

  def location_of_closest_enemy
    enemy_locations = @map.select do |x,y_hash|
      y = y_hash.keys.first
      @enemy_location_to_info.key?([x,y])
    end
    x, y_hash = enemy_locations.min_by do |x,y_hash|
      y_hash.keys.min_by do |y|
        get_distance_away([x,y])
      end
    end
    [x, y_hash.keys.first]
  end

  def location_of_closest_safe_space
    safe_locations = @map.select do |x,y_hash|
      y = y_hash.keys.first
      @unsafe_locations.include?([x,y])
    end
    x, y_hash = safe_locations.min_by do |x,y_hash|
      y_hash.keys.min_by do |y|
        get_distance_away([x,y])
      end
    end
    [x, y_hash.keys.first]
  end

  # Removes enemy at given location from @enemy_location_to_info hash.
  def unregister_enemy_at!(location)
    info = @enemy_location_to_info[location]
    # Mark all the locations that the enemy was attacking as safe.
    # This assumes that the enemy was the only thing attacking the locations
    # in its influence.
    enemy_influence(location, info[:character]).each{|loc| mark_safe_location!(loc) }
    @just_killed_an_enemy = true
    @enemy_location_to_info.delete(location)
  end

  # Decrement the health of the enemy at the given location, unregistering them if they died.
  def decrement_enemys_health_at(location)
    @enemy_location_to_info[location][:health] -= Player::ATTACK_POWER
    if @enemy_location_to_info[location][:health] <= 0
      # Enemy died
      unregister_enemy_at!(location)
    end
  end

  # Get info about a specific enemy
  def get_info_about_enemy_at(location)
    @enemy_location_to_info[location]
  end
end
