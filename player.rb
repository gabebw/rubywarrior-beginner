class Player
  MAX_HEALTH = 20
  # When we have less than this % health, rest (unless we're not in a safe
  # space)
  MINIMUM_PERCENT_HEALTH = 70
  def play_turn(warrior)
    @warrior = warrior
    @previous_health ||= current_health
    taking_damage = (current_health < @previous_health)
    space = warrior.feel
    if space.stairs?
      warrior.walk!
    elsif space.captive?
      warrior.rescue!
    elsif space.enemy?
      warrior.attack!
    elsif space.empty?
      if should_rest?
        # Regain some health
        warrior.rest!
      else
        warrior.walk!
      end
    else
      puts "Weird space: #{space.inspect}"
    end
    # available methods for a Space (returned by warrior.feel)
    # stairs?
    # empty?
    # enemy?
    # captive?
    # wall?
    # ticking? (OMINOUS!)
    # Note that the stairs space is empty, i.e.
    # if warrior.feel.stairs? is true, then warrior.feel.empty? is true too
    #
    # Set @previous_health for next turn
    @previous_health = current_health
  end

  # Is this space safe to rest in?
  def in_safe_space?
    space = @warrior.feel
    (space.empty? or space.captive? or space.wall?)
  end

  # Should the warrior rest?
  def should_rest?
    in_safe_space? and low_on_health? and
      not taking_damage? and # Not in danger
      not @warrior.feel.stairs? # No need to rest when we're about to clear the level
  end

  def current_health
    @warrior.health
  end

  def taking_damage?
    taking_damage = (current_health < @previous_health)
  end

  def low_on_health?
    percent_health = (current_health.to_f / MAX_HEALTH) * 100
    percent_health < MINIMUM_PERCENT_HEALTH
  end
end
