class My::SolutionsController < MyController
  before_action :set_solution, except: [:create]

  def create
    track = Track.find(params[:track_id])
    exercise = track.exercises.find(params[:exercise_id])

    # If this is a side exercise that has no unlocked_by
    # the you can unlock it. This is the only time this method
    # is allowed to be called.
    if !exercise.core && !exercise.unlocked_by
      solution = CreatesSolution.create!(current_user, exercise)
      redirect_to [:my, solution]
    else
      redirect_to [:my, track]
    end
  end

  def show
    @exercise = @solution.exercise
    ClearsNotifications.clear!(current_user, @solution)

    @track = @solution.exercise.track
    @user_track = UserTrack.where(user: current_user, track: @track).first

    if @solution.iterations.size > 0
      show_started
    else
      show_unlocked
    end
  end

  def walkthrough
    render_modal("solution-walkthrough autoclose", "walkthrough")
  end

  def confirm_unapproved_completion
    render_modal('solution-confirm-unapproved-completion', "confirm_unapproved_completion")
  end

  def complete
    #CompletesSolution.complete!(@solution)
    @exercise = @solution.exercise
    @track = @exercise.track
    @num_completed_exercises = current_user.solutions.where(exercise_id: @track.exercises).completed.count
    render_modal("solution-completed", "complete")
  end

  def reflection
    @mentor_interations = @solution.discussion_posts.group(:user_id).count
    p @mentor_interations
    render_modal("solution-reflection", "reflection")
  end

  def reflect
    @solution.update(reflection: params[:reflection])
    (params[:mentor_reviews] || {}).each do |mentor_id, data|
      ReviewsSolutionMentoring.review!(
        @solution,
        User.find(mentor_id),
        data[:rating],
        data[:feedback]
      )
    end
    @track = @solution.exercise.track

    # TODO - if this is a side exercise, it won't unlock a core.
    @next_core_exercise = current_user.solutions.not_completed.
                          joins(:exercise).
                          where("exercises.track_id": @track.id).
                          where("exercises.core": true).
                          first.exercise

    @unlocked_side_exercises = @solution.exercise.unlocks

    render_modal("solution-unlocked", "unlocked")
  end

  private
  def set_solution
    @solution = current_user.solutions.find_by_uuid!(params[:id])
  end

  def show_unlocked
    render :show_unlocked
  end

  def show_started
    @iteration = @solution.iterations.offset(params[:iteration_idx].to_i - 1).first if params[:iteration_idx].to_i > 0
    @iteration = @solution.iterations.last unless @iteration
    @iteration_idx = @solution.iterations.where("id < ?", @iteration.id).count + 1
    @num_iterations = @solution.iterations.count

   render :show
  end
end
