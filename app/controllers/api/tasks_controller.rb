# frozen_string_literal: true

class Api::TasksController < Api::BaseController
  include Authorizable

  before_action :set_project, only: %i[index create]
  before_action :set_task, only: %i[update destroy]
  before_action :authorize_project_member!

  def index
    tasks = @project.tasks
    tasks = tasks.by_status(params[:status]) if params[:status].present?
    tasks = tasks.by_priority(params[:priority]) if params[:priority].present?
    tasks = tasks.by_assignee(params[:assignee_id]) if params[:assignee_id].present?

    paginated, pagination = paginate(tasks)

    render_success(data: {
      tasks: paginated.includes(:assignee).map(&:as_api_json),
      pagination: pagination
    })
  end

  def create
    task = @project.tasks.new(task_params)

    if task.assignee_id.present? && !@project.memberships.exists?(user_id: task.assignee_id)
      return render_error(errors: { assignee: ["must be a project member"] }, status: :unprocessable_entity)
    end

    if task.save
      render_success(data: { task: task.as_api_json }, status: :created)
    else
      render_error(errors: task.errors.to_hash(true), status: :unprocessable_entity)
    end
  end

  def update
    if task_params[:assignee_id].present? && !@project.memberships.exists?(user_id: task_params[:assignee_id])
      return render_error(errors: { assignee: ["must be a project member"] }, status: :unprocessable_entity)
    end

    if @task.update(task_params)
      render_success(data: { task: @task.as_api_json })
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

  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :due_date, :assignee_id)
  end
end
