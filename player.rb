class Player
  MAX_HEALTH = 20
  # How much damage the warrior does per turn
  DAMAGE_DEALT = 5
  # When we have less than this % health, rest (unless we're not in a safe
  # space)
  MINIMUM_PERCENT_HEALTH = 50
  ENEMY = {:S => {:health => 24, :damage => 3},
           :a => {:health => 7, :damage => 3}}
  DIRECTIONS = [:forward, :backward]

  def play_turn(warrior)
    # warrior.action returns [:latest_action, :direction_it_was_performed]
    @warrior = warrior
    @previous_health ||= current_health
    @previous_space ||= current_location

    perform_action!(warrior)

    # Set variables for next turn
    @previous_health = current_health
    @previous_location = current_location
  end

  # Performs a bang-action, e.g. walk!
  def perform_action!(warrior)
    # available methods for a Space (returned by warrior.feel)
    # TESTERS
    #   stairs?
    #   empty?
    #   enemy?
    #   captive?
    #   wall?
    #   ticking? (OMINOUS!)
    # TYPE GETTERS
    #   unit (e.g. "Thick Sludge", may be nil)
    #   location - An [X-coord, Y-coord] pair
    #     - A coordinate may be < 0, e.g. if you're at [0, 0],
    #       then warrior.feel(:backward).location = [-1, 0]
    #   character (e.g. "S" for a thick sludge, may be nil)
    # Note that the stairs space is empty (unless a unit is on it), i.e.
    # space.empty? returns true for the stairs space, so explicitly check
    # for stairs.

    # We can get away with only feeling in one direction, for now.
    space = warrior.feel(direction)

    # The stairs space may not be empty, e.g. if an enemy or captive is on
    # it
    if space.stairs? and space.empty?
      warrior.walk!(direction)
    elsif current_location == [1, 0] and warrior.feel(:backward).empty?
      # Nothing more to do here
      @direction = :forward
      warrior.walk!(direction)
    elsif should_rest?
      if in_safe_space?
        # Regain some health
        mark_safe_location!
        warrior.rest!
      else
        puts "Should rest, but not in safe space. Moving towards it."
        move_toward_safe_space!
      end
    elsif space.captive?
      warrior.rescue!(direction)
    elsif space.enemy?
      location_of_closest_enemy = space.location
      warrior.attack!(direction)
    elsif space.empty?
      # May have just moved away from an enemy, so check if we should
      # re-engage.
      if location_of_closest_enemy.nil?
        # No enemies, blithely continue
        warrior.walk!(direction)
      else
        move_toward_most_recent_enemy!
      end
    elsif taking_damage_from_afar? and should_rest?
      puts "Should move away from threat"
      # Move away from threat
      move_toward_safe_space!
    elsif space.wall?
      # Hit a wall, switch direction and retry
      reverse_direction!
      perform_action!(warrior)
    else
      puts "!!! Weird space: #{space.inspect}"
      warrior.walk!(direction)
    end
  end

  # STATE CHANGERS

  def reverse_direction!
    @direction = opposite_direction_of(direction)
  end

  # Moves warrior toward a safe space
  def move_toward_safe_space!
    puts "Moving toward safe space"
    if taking_damage_from_afar? and should_rest?
      # Move away from threat
      @direction = away_from(location_of_closest_enemy)
    else
      reverse_direction!
    end
    @warrior.walk!(direction)
  end

  def move_toward_most_recent_enemy!
    @direction = towards(location_of_closest_enemy)
    @warrior.walk!(direction)
  end

  # Mark the current location as safe
  def mark_safe_location!
    @safe_locations ||= []
    @safe_locations << current_location unless @safe_locations.include?(current_location)
  end

  ## TESTERS

  # Is this space safe to rest in?
  # Note that it doesn't take into account whether the warrior is taking
  # damage.
  def in_safe_space?
    not taking_damage? and not next_to_enemy?
  end

  # Is a given location safe?
  def is_safe_location?(location)
    @safe_locations.include?(location)
  end

  # Should the warrior rest? Note that this doesn't take into account
  # whether it's safe for the warrior to rest, it just recommends that he
  # should.
  def should_rest?
    # No need to rest when we're about to clear the level
    low_on_health? and not @warrior.feel(direction).stairs?
  end

  # Is an enemy in an adjacent space?
  def next_to_enemy?
    DIRECTIONS.any? { |dir| @warrior.feel(dir).enemy? }
  end

  def taking_damage?
    current_health < @previous_health
  end

  def taking_damage_from_afar?
    taking_damage? and not next_to_enemy?
  end

  # Did we just start taking damage this turn?
  def just_started_taking_damage?
    taking_damage? and is_safe_location?(@previous_location)
  end

  def low_on_health?
    percent_health = (current_health.to_f / MAX_HEALTH) * 100
    percent_health < MINIMUM_PERCENT_HEALTH
  end

  # ACCESSORS

  def current_health
    @warrior.health
  end

  def current_turn
    @current_turn ||= 1
  end

  # Get direction warrior is walking in. Defaults to :backward.
  def direction
    @direction ||= :backward
  end

  # Returns direction of most recent enemy that the warrior engaged (or just
  # took damage from), or nil if the warrior has yet to encounter an enemy
  #def direction_of_most_recent_enemy
    # Default to nil so we can tell when we have yet to engage an enemy
  #  @direction_of_most_recent_enemy ||= nil
  #end

  def current_location
    backward = @warrior.feel(:backward).location
    x_coord = backward[0] + 1
    y_coord = backward[1]
    [x_coord, y_coord]
  end

  def location_of_closest_enemy=(location)
    @enemy_location = location
  endk

  # UTILITY
  def opposite_direction_of(dir)
    case dir
    when :forward then :backward
    when :backward then :forward
    end
  end

  # Pass in an enemy character, like "S", to determine how many turns it
  # will take to kill it
  def turns_required_to_beat(enemy)
    enemy = enemy.to_sym
    (ENEMY[enemy][:health].to_f / DAMAGE_DEALT).ceil
  end

  # Do we have enough health to engage in battle?
  def healthy_enough_to_beat?(enemy)
    turns = turns_required_to_beat(enemy)
    predicted_damage_taken = turns * ENEMY[enemy][:damage]
    predicted_damage_taken < current_health
  end

  # Returns location of closest enemy. May be nil.
  def location_of_closest_enemy
    @enemy_location ||= nil
    x,y = current_location
    if taking_damage?
      dir = DIRECTIONS.detect?{|d| @warrior.feel(d).enemy? }
      @enemy_location = @warrior.feel(dir).location
    elsif taking_damage_from_afar? and just_started_taking_damage?
      # Archer is shooting at us. They have a range of 2 squares.
      # i.e. |@  a| is sufficient
      @enemy_location = [x+3, y]
    end
    @enemy_location
  end

  # Returns a direction that will bring the warrior closer to the given location.
  def towards(location)
    target_x, target_y = location
    current_x, current_y = current_location
    current_x > target_x ? :backward : :forward
  end

  # Returns a direction that will bring the warrior farther away from the given location.
  def away_from(location)
    opposite_direction_of(towards(location)
  end
end
