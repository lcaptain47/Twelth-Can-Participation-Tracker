# frozen_string_literal: true

require 'time'
class TimeslotsController < ApplicationController
  # Prepares new timeslot form
  def new
    @event = Event.find(params[:event_id])

    redirect_to event_path(@event) unless current_user.user_role.can_create
    @timeslot = Timeslot.new(event_id: params[:event_id])
  end

  # Post Route function for timeslot
  def create
    @event = Event.find(params[:timeslot][:event_id])
    redirect_to event_path(@event) unless current_user.user_role.can_create

    # Used as increment
    count = params[:timeslot][:count].to_i

    # Formats time parameters for use in Time object
    start_time_hour = params[:timeslot]['start_time(4i)'].to_i
    end_time_hour = params[:timeslot]['end_time(4i)'].to_i
    start_time_minute = params[:timeslot]['start_time(5i)'].to_i
    end_time_minute = params[:timeslot]['end_time(5i)'].to_i

    # Formats start time
    minutes = start_time_minute
    hours = start_time_hour
    string_time = "#{hours}:#{minutes}"

    # Creates Time objects for start and end time
    end_time = Time.find_zone('UTC').parse("#{end_time_hour}:#{end_time_minute}")
    time = Time.find_zone('UTC').parse(string_time)

    # Redirects to new form if count is not provided and if start time is larger than end time
    # Creates Timeslot objects otherwise
    if time >= end_time || count < 10
      flash[:notice] = 'You cannot use an end time smaller than  or equal to your start time'
      redirect_to new_timeslot_path(event_id: params[:timeslot][:event_id])
    else
      event = Event.find(params[:timeslot][:event_id])

      # Creates timeslots for each role
      create_timeslots(time, end_time, count, event, 'Volunteer', event.volunteers)
      create_timeslots(time, end_time, count, event, 'Front Desk', event.front_desks)
      create_timeslots(time, end_time, count, event, 'Runner', event.runners)

      # Redirects to the event page for the timslots' event
      @eventid = params[:timeslot][:event_id]
      @event_exit = Event.find(@eventid)
      redirect_to @event_exit
    end
  end

  # Claims an unclaimed timeslot
  def claim
    timeslot = Timeslot.find(params[:id])
    if !timeslot.user.nil?
      flash[:notice] = 'Timeslot is already claimed claimed'
      @events = Event.all
      redirect_to events_path
    else
      flash[:notice] =
        "You have claimed the timeslot at #{timeslot.time.strftime('%l:%M %P')}
         for the role #{timeslot.role} #{timeslot.role_number}"

      # timeslot.is_approved = false
      timeslot.user = current_user

      user = current_user
      user.total_unapproved_hours += timeslot.duration
      user.save
      timeslot.save

      redirect_to event_path(timeslot.event)
    end
  end

  # Unclaims a claimed timeslot if the user owned it or if the user has the right permissions
  def unclaim
    timeslot = Timeslot.find(params[:id])
    user = timeslot.user
    if current_user.id == timeslot.user_id || current_user.user_role.can_claim_unclaim
      flash[:notice] =
        "You have unclaimed the timeslot at #{timeslot.time.strftime('%l:%M %P')}
         for the role #{timeslot.role} #{timeslot.role_number}"

      if timeslot.is_approved
        user.total_approved_hours -= timeslot.duration

        case timeslot.role
        when 'Front Desk'
          user.front_office_hours -= timeslot.duration
        when 'Runner'
          user.pantry_runner_hours -= timeslot.duration
        when 'Volunteer'
          user.volunteer_hours -= timeslot.duration
        end

      else
        user.total_unapproved_hours -= timeslot.duration

      end
      user.save
      timeslot.is_approved = false
      timeslot.user = nil
      timeslot.save
    end
    redirect_to event_path(timeslot.event)
  end

  # Approves timeslot and increments respective hours for owner of timeslot
  def approve
    return unless current_user.user_role.can_approve_unapprove

    timeslot = Timeslot.find(params[:id])
    timeslot.is_approved = true
    user = timeslot.user

    case timeslot.role
    when 'Front Desk'
      user.front_office_hours += timeslot.duration
    when 'Runner'
      user.pantry_runner_hours += timeslot.duration
    when 'Volunteer'
      user.volunteer_hours += timeslot.duration
    end
    user.total_approved_hours += timeslot.duration
    user.total_unapproved_hours -= timeslot.duration

    user.save
    timeslot.save
    flash[:notice] = "You have approved the timeslot at #{timeslot.time.strftime('%l:%M %P')}
    for the role #{timeslot.role} #{timeslot.role_number} for the user #{timeslot.user.full_name}"
    redirect_to(event_path(timeslot.event))
  end

  # Unapproves timeslot and decrements respective hours for owner of timeslot
  def unapprove
    return unless current_user.user_role.can_approve_unapprove

    timeslot = Timeslot.find(params[:id])
    timeslot.is_approved = false
    user = timeslot.user

    case timeslot.role
    when 'Front Desk'
      user.front_office_hours -= timeslot.duration
    when 'Runner'
      user.pantry_runner_hours -= timeslot.duration
    when 'Volunteer'
      user.volunteer_hours -= timeslot.duration
    end
    user.total_unapproved_hours += timeslot.duration
    user.total_approved_hours -= timeslot.duration

    user.save
    timeslot.save
    flash[:notice] = "You have unapproved the timeslot at #{timeslot.time.strftime('%l:%M %P')}
    for the role #{timeslot.role} #{timeslot.role_number} for the user #{timeslot.user.full_name}"
    redirect_to(event_path(timeslot.event))
  end

  private

  # Generalizes timeslot creation for each role
  def create_timeslots(start_time, end_time, count, _event, role_name, role_amount)
    role_number = 0

    role_amount.times do
      time = start_time
      role_number += 1

      input_role = role_name.to_s

      while time < end_time && time + (count * 60) <= end_time

        timeslot = Timeslot.new
        timeslot.time = time
        timeslot.duration = count
        timeslot.event_id = params[:timeslot][:event_id]
        timeslot.role = input_role
        timeslot.role_number = role_number
        timeslot.is_approved = false

        timeslot.save

        time += (count * 60)
      end
    end
  end
end
