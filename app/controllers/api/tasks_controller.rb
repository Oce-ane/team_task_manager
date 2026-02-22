# frozen_string_literal: true

class Api::TasksController < Api::BaseController
  before_action :set_project, only: %i[index create]
  before_action :set_task, only: %i[update destroy]
  before_action :authorize_project_member!

  def index
    tasks = @project.tasks
    tasks = tasks.by_status(params[:status]) if params[:status].present?
    tasks = tasks.by_priority(params[:priority]) if params[:priority].present?
    tasks = tasks.by_assignee(params[:assignee_id]) if params[:assignee_id].present?

    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 25).to_i
    total = tasks.count
    paginated = tasks.offset((page - 1) * per_page).limit(per_page)

    render_success(data: {
      tasks: paginated.includes(:assignee).map { |t| task_json(t) },
      pagination: { page: page, per_page: per_page, total: total, pages: (total.to_f / per_page).ceil }
    })
  end

  def create
    task = @project.tasks.new(task_params)

    if task.assignee_id.present? && !@project.memberships.exists?(user_id: task.assignee_id)
      return render_error(errors: { assignee: ["must be a project member"] }, status: :unprocessable_entity)
    end

    if task.save
      render_success(data: { task: task_json(task) }, status: :created)
    else
      render_error(errors: task.errors.to_hash(true), status: :unprocessable_entity)
    end
  end

  def update
    if task_params[:assignee_id].present? && !@project.memberships.exists?(user_id: task_params[:assignee_id])
      return render_error(errors: { assignee: ["must be a project member"] }, status: :unprocessable_entity)
    end

    if @task.update(task_params)
      render_success(data: { task: task_json(@task) })
    else
      render_error(errors: @task.errors.to_hash(true), status: :unprocessable_entity)
    end
  end

  def destroy
    @task.destroy!
    render_success(data: { message: "Task deleted" })
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_error(errors: { project: ["Not found"] }, status: :not_found)
  end

  def set_task
    @task = Task.find(params[:id])
    @project = @task.project
  rescue ActiveRecord::RecordNotFound
    render_error(errors: { task: ["Not found"] }, status: :not_found)
  end

  def authorize_project_member!
    return if @project && @project.memberships.exists?(user_id: current_user.id)

    render_error(errors: { project: ["Access denied"] }, status: :forbidden)
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :due_date, :assignee_id)
  end

  def task_json(task)
    {
      id: task.id, project_id: task.project_id, title: task.title,
      description: task.description, status: task.status, priority: task.priority,
      due_date: task.due_date, assignee_id: task.assignee_id,
      assignee: task.assignee ? user_json(task.assignee) : nil,
      created_at: task.created_at, updated_at: task.updated_at
    }
  end

  def user_json(user)
    { id: user.id, email: user.email, name: user.name }
  end
end
