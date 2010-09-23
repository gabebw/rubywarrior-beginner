class Player
  MAX_HEALTH = 20
  # When we have less than this % health, rest (unless we're not in a safe
  # space)
  MINIMUM_PERCENT_HEALTH = 70
  ENEMY_HEALTH = {:thick_sludge => 24,
                  :archer => 7 }
  # Yay, Ruby 1.9! Yes, I'm using a lambda only so it takes up less space.
  AVG_ENEMY_HEALTH = ->(v){v.inject{|acc,x|acc+x}/v.size.to_f}.call(ENEMY_HEALTH.values)
  DIRECTIONS = [:forward, :backward]

  def play_turn(warrior)
    @warrior = warrior
    @previous_health ||= current_health

    perform_action!(warrior)

    # Set @previous_health for next turn
    @previous_health = current_health
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
    elsif should_rest?
      if in_safe_space?
        # Regain some health
        mark_safe_space!
        warrior.rest!
      else
        puts "Should rest, but not in safe space. Moving towards it."
        move_toward_safe_space!
      end
    elsif space.captive?
      warrior.rescue!(direction)
    elsif space.enemy?
      set_most_recent_enemy_direction!
      warrior.attack!(direction)
    elsif space.empty?
      # May have just moved away from an enemy, so check if we should
      # re-engage.
      if direction_of_most_recent_enemy.nil?
        # No enemies, blithely continue
        warrior.walk!(direction)
      else
        move_toward_most_recent_enemy!
      end
    elsif taking_damage_from_afar? and should_rest?
      puts "Should move away from threat"
      set_most_recent_enemy_direction!
      # Move away from threat
      move_toward_safe_space!
    elsif space.wall?
      # Hit a wall, switch direction and retry
      reverse_direction!
      perform_action!(warrior)
    else
      puts "Weird space: #{space.inspect}"
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
      @direction = opposite_direction_of(direction_of_most_recent_enemy)
    else
      reverse_direction!
    end
    @warrior.walk!(direction)
  end

  # Returns direction of most recent enemy that the warrior engaged (or just
  # took damage from), or nil if the warrior has yet to encounter an enemy
  def direction_of_most_recent_enemy
    #@direction_of_most_recent_enemy ||= direction
    # Default to nil so we can tell when we have yet to engage an enemy
    @direction_of_most_recent_enemy ||= nil
  end

  # Set the direction of the most recent enemy to the current direction.
  # Only called when warrior is engaging an enemy (or just taking damage
  # from it).
  def set_most_recent_enemy_direction!
    @direction_of_most_recent_enemy = direction
  end

  def move_toward_most_recent_enemy!
    @direction = direction_of_most_recent_enemy
    @warrior.walk!(direction)
  end

  # Mark the current space as safe
  def mark_safe_space!
    @safe_spaces ||= []
    backward = @warrior.feel(:backward)
    x_coord = backward[0] + 1
    y_coord = backward[1] + 1
    @safe_spaces << [x_coord, y_coord]
  end

  ## TESTERS

  # Is this space safe to rest in?
  # Note that it doesn't take into account whether the warrior is taking
  # damage.
  def in_safe_space?
    not taking_damage? and not next_to_enemy?
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

  # UTILITY
  def opposite_direction_of(dir)
    case dir
    when :forward then :backward
    when :backward then :forward
    end
  end
end
