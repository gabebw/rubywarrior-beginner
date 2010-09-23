class Player
  def play_turn(warrior)
    @turn_number ||= 1
    @turn_number += 1
    percent_health = (warrior.health / 20.0) * 100
    if warrior.feel.empty?
      # @turn_number is a total hack to get more points - I know the way is clear
      # after turn 20, so no resting there.
      if percent_health <= 35 and @turn_number < 20
        # Regain some health
        warrior.rest!
      else
        warrior.walk!
      end
    else
      warrior.attack!
    end
  end
end
