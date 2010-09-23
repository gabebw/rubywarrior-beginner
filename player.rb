class Player
  MAX_HEALTH = 20
  # When we have less than this % health, rest (unless we're not in a safe
  # space)
  MINIMUM_PERCENT_HEALTH = 70
  ENEMY_HEALTH = {:thick_sludge => 24,
                  :archer => 7 }
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
    # stairs?
    # empty?
    # enemy?
    # captive?
    # wall?
    # ticking? (OMINOUS!)
    # Note that the stairs space is empty, i.e.
    # if warrior.feel.stairs? is true, then warrior.feel.empty? is true too


    # We can get away with only feeling in one direction, for now.
    space = warrior.feel(direction)

    # The stairs space may not be empty, e.g. if an enemy or captive is on
    # it
    if space.stairs? and space.empty?
      warrior.walk!(direction)
    elsif should_rest?
      if in_safe_space?
        # Regain some health
        warrior.rest!
      else
        move_toward_safe_space!
      end
    elsif space.captive?
      warrior.rescue!(direction)
    elsif space.enemy?
      warrior.attack!(direction)
    elsif space.empty?
      puts "Empty space"
      warrior.walk!(direction)
    elsif taking_damage_from_afar? and should_rest?
      puts "Should move away from threat"
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
    @direction = (direction == :forward ? :backward : :forward)
  end

  # Moves warrior toward a safe space
  def move_toward_safe_space!
    puts "Moving toward safe space"
    #if taking_damage_from_afar? and should_rest?
      # Move away from threat
      reverse_direction!
      @warrior.walk!(direction)
    #end
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
end
