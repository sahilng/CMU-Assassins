# encoding: utf-8
require 'data_mapper'
require 'slim'

module Assassins
  class App < Sinatra::Base
    before do
      @player = nil
      if session.has_key? :player_id
        @player = Player.get session[:player_id]
        if @player.nil?
          session.delete :player_id
        end
      end
    end

    set(:logged_in) do |val|
      condition {!@player.nil? == val}
    end

    get '/login' do
      slim :login
    end

    post '/login' do
      player = Player.first(:andrew_id => params['andrew_id'])

      if (player.nil?)
        return slim :login, :locals => {:errors =>
          ['Invalid Andrew ID. Please try again.']}
      end

      if (!player.active?)
        if (!player.is_verified)
          return redirect to('/signup/resend_verification')
        else
          return slim :login, :locals => {:errors =>
            ['You have been assassinated and your account made inactive. Thanks for playing!']}
        end
      end

      if (!(params.has_key?('secret') &&
            player.secret.casecmp(params['secret']) == 0))
        return slim :login, :locals => {:errors =>
          ['Incorrect secret words. Please try again.']}
      end

      session[:player_id] = player.id
      redirect to('/dashboard')
    end

    get '/logout' do
      session.delete :player_id
      redirect to('/')
    end

    get '/signup' do
      slim :signup
    end

    post '/signup' do
      if (params.has_key?('andrew_id') && params['andrew_id'].index('@'))
        return slim :signup, :locals => {:errors =>
          ['Please enter only your Andrew ID, not your full email address.']};
      end

      player = Player.new(:name => params['name'],
                          :andrew_id => params['andrew_id'],
                          :floor_id => params['floor'],
                          :program_id => params['program'])
      player.generate_secret! 2
      if (player.save)
        player.send_verification(settings.mailer, url("/signup/verify?aid=#{player.andrew_id}&nonce=#{player.verification_key}"))
        slim :signup_confirm
      else
        slim :signup, :locals => {:errors => player.errors.full_messages}
      end
    end

    get '/signup/resend_verification' do
      slim :resend_verification
    end

    post '/signup/resend_verification' do
      player = Player.first(:andrew_id => params['andrew_id'])
      if (player.nil?)
        return slim :resend_verification, :locals => {:errors =>
          ['Invalid Andrew ID']}
      end

      if (player.is_verified)
        return slim :resend_verification, :locals => {:errors =>
          ['That account has already been verified. You can log in using the form above.']}
      end

      player.verification_key = SecureRandom.uuid
      player.save!
      player.send_verification(settings.mailer, url("/signup/verify?aid=#{player.andrew_id}&nonce=#{player.verification_key}"))
      slim :signup_confirm
    end

    get '/signup/verify' do
      player = Player.first(:andrew_id => params['aid'])

      if (player.nil? || player.is_verified)
        return redirect to('/')
      end

      if (params.has_key?('nonce') && params['nonce'] == player.verification_key)
        player.is_verified = true;
        player.save!;
        session[:player_id] = player.id
        redirect to('/dashboard')
      else
        redirect to('/')
      end
    end

    get '/dashboard', :logged_in => true do
      slim :dashboard
    end

    post '/dashboard/assassinate', :logged_in => true do
      target = @player.target
      if (params.has_key?('target_secret') &&
          target.secret.casecmp(params['target_secret']) == 0)
        @player.set_target_notify(settings.mailer, target.target)
        redirect to('/dashboard')
      else
        slim :dashboard, :locals => {:errors =>
          ["That isn't your target's secret. Please try again."]}
      end
    end

    get /^\/dashboard(\/.*)?$/, :logged_in => false do
      redirect to('/login')
    end
 end
end

# vim:set ts=2 sw=2 et:
