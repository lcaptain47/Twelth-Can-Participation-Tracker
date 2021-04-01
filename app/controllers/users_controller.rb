# frozen_string_literal: true

class UsersController < ApplicationController
  # Shows user info
  def show
    @user = User.find(params[:id])
  end

  def promote
    user = User.find(params[:id])

    return unless current_user.user_role.can_promote_demote

    if user.user_role.name == 'User'
      user.user_role = UserRole.find_by(name: 'Officer')
      user.save
      redirect_to user_path(user)
      return
    end

    if user.user_role.name == 'Officer'
      user.user_role = UserRole.find_by(name: 'President')
      user.save
      current_user.user_role = UserRole.find_by(name: 'User')
      current_user.save
      redirect_to user_path(user)
    end
  end

  def demote
    user = User.find(params[:id])

    redirect_to root_path if current_user.uid == user.uid

    return unless current_user.user_role.can_promote_demote && (user.user_role.name == 'Officer')

    user.user_role = UserRole.find_by(name: 'User')
    user.save

    redirect_to user_path(user)
  end
end
