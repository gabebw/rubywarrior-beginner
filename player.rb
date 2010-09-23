class Player
  MAX_HEALTH = 20
  def play_turn(warrior)
    current_health = warrior.health
    @previous_health ||= current_health
    percent_health = (current_health.to_f / MAX_HEALTH) * 100
    taking_damage = (current_health < @previous_health)
    space = warrior.feel
    if space.stairs?
      warrior.walk!
    elsif space.empty?
      # warrior might be attacked even if space ahead is empty
      # So if we're low on health and not taking damage, rest a bit.
      if percent_health < 60 and not taking_damage and not space.stairs?
        # Regain some health
        warrior.rest!
      else
        warrior.walk!
      end
    else
      if space.enemy?
        warrior.attack!
      end
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
end
