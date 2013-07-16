SimpleNavigation::Configuration.run do |navigation|
  logged_in_proc = Proc.new {logged_in?}

  navigation.items do |primary|
    primary.dom_class = 'nav'
    primary.selected_class = 'active'
    primary.item :signup, 'Sign Up', url('/signup'), :unless => logged_in_proc
    primary.item :dashboard, 'Dashboard', url('/dashboard'), :if => logged_in_proc
    primary.item :leaderboard, 'Leaderboards', url('/leaderboard')
    primary.item :rules, 'Rules', url('/rules')
  end
end

# vim:set ts=2 sw=2 et:
