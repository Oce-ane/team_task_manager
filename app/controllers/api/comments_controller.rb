# frozen_string_literal: true

class Api::CommentsController < Api::BaseController
  before_action :set_task, only: %i[index create]
  before_action :set_comment, only: %i[update destroy]
  before_action :authorize_project_member!, only: %i[index create]
  before_action :authorize_comment_author!, only: %i[update destroy]

  def index
    comments = @task.comments.includes(:user).order(created_at: :asc)

    render_success(data: { comments: comments.map { |c| comment_json(c) } })
  end

  def create
    comment = @task.comments.new(comment_params.merge(user: current_user))

    if comment.save
      CommentNotificationJob.perform_later(comment.id)
      render_success(data: { comment: comment_json(comment) }, status: :created)
    else
      render_error(errors: comment.errors.to_hash(true), status: :unprocessable_entity)
    end
  end

  def update
    if @comment.update(comment_params)
      render_success(data: { comment: comment_json(@comment) })
    else
      render_error(errors: @comment.errors.to_hash(true), status: :unprocessable_entity)
    end
  end

  def destroy
    @comment.destroy!
    render_success(data: { message: "Comment deleted" })
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
    @project = @task.project
  rescue ActiveRecord::RecordNotFound
    render_error(errors: { task: ["Not found"] }, status: :not_found)
  end

  def set_comment
    @comment = Comment.find(params[:id])
    @task = @comment.task
    @project = @task.project
  rescue ActiveRecord::RecordNotFound
    render_error(errors: { comment: ["Not found"] }, status: :not_found)
  end

  def authorize_project_member!
    return if @project&.memberships&.exists?(user_id: current_user.id)

    render_error(errors: { project: ["Access denied"] }, status: :forbidden)
  end

  def authorize_comment_author!
    return if @comment&.user_id == current_user.id

    render_error(errors: { comment: ["You can only modify your own comments"] }, status: :forbidden)
  end

  def comment_params
    params.require(:comment).permit(:content)
  end

  def comment_json(comment)
    {
      id: comment.id, task_id: comment.task_id, content: comment.content,
      created_at: comment.created_at, updated_at: comment.updated_at,
      user: { id: comment.user.id, email: comment.user.email, name: comment.user.name }
    }
  end
end
