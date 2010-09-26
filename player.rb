require './map'
class Player
  # When we have less than this % health, rest (unless we're not in a safe
  # space)

  ATTACK_POWER = 5
  MAX_HEALTH = 20
  MINIMUM_PERCENT_HEALTH = 50

  def set_variables!(warrior)
    @warrior = warrior
    @previous_health = current_health
    # If true, then rest until at max health before continuing
    @recuperating = false
    @just_killed_an_enemy = false
    @map = Map.new(self, warrior)

    @already_set_variables = true
  end

  attr_accessor :direction

  def play_turn(warrior)
    # warrior.action returns [:latest_action, :direction_it_was_performed]
    set_variables!(warrior) unless @already_set_variables
    @warrior = warrior # yes, you have to set this each time
    @map.update!(warrior)

    perform_action!(warrior)

    # Set variables for next turn
    previous_health = current_health
    @map.previous_location = current_location
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
      #@just_killed_an_enemy = false
      if in_safe_space?
        # Regain some health
        @map.mark_safe_location!(current_location)
        warrior.rest!
      else
        puts "Should rest, but not in safe space. Moving towards it."
        @recuperating = true
        reverse_direction!
        @direction = @map.towards_safe_space
        warrior.walk!(direction)
      end
    elsif space.captive?
      warrior.rescue!(direction)
    elsif space.enemy?
      #attack_enemy!
      @map.register_current_enemy!
      @map.decrement_current_enemys_health_by(ATTACK_POWER)
      warrior.attack!(direction)
    elsif space.empty?
      # May have just moved away from an enemy, so check if we should
      # re-engage.
      if @map.location_of_current_enemy.nil?
        # No enemies, blithely continue
        warrior.walk!(direction)
      else
        @direction = @map.towards_current_enemy
        warrior.walk!(direction)
      end
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
    @direction = @map.opposite_direction_of(direction)
  end

  # A wrapper around warrior.attack!(direction) so we can track an enemy's
  # health.
  def attack_enemy!
    location = @warrior.feel(direction).location
    @map.register_current_enemy!
    @map.decrement_current_enemys_health_by(ATTACK_POWER)
    @warrior.attack!(direction)
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
    return false if @warrior.feel(direction).stairs?
    return false if @warrior.health == MAX_HEALTH

    if @recuperating
      # Stop recuperating if at max health
      @recuperating = @warrior.health < MAX_HEALTH
      return @recuperating
    elsif @map.current_enemy
      not healthy_enough_to_beat_enemy_at?(@map.get_current_enemy_info[:location])
    else
      low_on_health?
    end
  end

  # Is an enemy in an adjacent space?
  def next_to_enemy?
    Map::DIRECTIONS.any? { |dir| @warrior.feel(dir).enemy? }
  end

  def taking_damage?
    current_health < @previous_health
  end

  def taking_damage_from_afar?
    taking_damage? and not next_to_enemy?
  end

  # Did we just start taking damage this turn?
  def just_started_taking_damage?
    taking_damage? and @map.is_safe_location?(@previous_location)
  end

  def low_on_health?
    percent_health = (current_health.to_f / MAX_HEALTH) * 100
    percent_health < MINIMUM_PERCENT_HEALTH
  end

  # ACCESSORS

  def current_health
    @warrior.health
  end

  # Get direction warrior is walking in. Defaults to :backward.
  def direction
    @direction ||= :backward
  end

  # UTILITY
  # Pass in an enemy location to determine how many turns it
  # will take to kill it once you're next to it.
  def turns_required_to_beat_enemy_at(enemy_location)
    info = @map.get_info_about_enemy_at(enemy_location)
    turns = (info[:health].to_f / ATTACK_POWER).ceil
    turns
  end

  def current_location
    backward = @warrior.feel(:backward).location
    x_coord = backward[0] + 1
    y_coord = backward[1]
    [x_coord, y_coord]
  end

  # Do we have enough health to engage in battle?
  def healthy_enough_to_beat_enemy_at?(enemy_location)
    turns = turns_required_to_beat_enemy_at(enemy_location)
    enemy_info = @map.get_info_about_enemy_at(enemy_location)
    # Archers attack from a distance of 2 squares, but if we're right next
    # to them then we need fewer turns
    turns += [2, @map.get_distance_away(enemy_info[:location])].min if enemy_info[:character] == :a
    puts "turns reqd: #{turns}"
    predicted_damage_taken = turns * enemy_info[:damage]
    predicted_damage_taken < current_health
  end
end
