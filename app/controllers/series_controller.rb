class SeriesController < ApplicationController
 include CommonCreatorship

  before_action :check_user_status, only: [:new, :create, :edit, :update]
  before_action :load_series, only: [ :show, :edit, :update, :manage, :destroy, :confirm_delete ]
  before_action :check_ownership, only: [ :edit, :update, :manage, :destroy, :confirm_delete ]
  before_action :check_visibility, only: [:show]
  before_action :set_author_attributes, only: [:create, :update]

  def load_series
    @series = Series.find_by(id: params[:id])
    unless @series
      raise ActiveRecord::RecordNotFound, "Couldn't find series '#{params[:id]}'"
    end
    @check_ownership_of = @series
    @check_visibility_of = @series
  end

  # GET /series
  # GET /series.xml
  def index
    if params[:user_id]
      @user = User.find_by(login: params[:user_id])
      unless @user
        raise ActiveRecord::RecordNotFound, "Couldn't find user '#{params[:user_id]}'"
      end
      @page_subtitle = ts("%{username} - Series", username: @user.login)
      pseuds = @user.pseuds
      if params[:pseud_id]
        @pseud = @user.pseuds.find_by(name: params[:pseud_id])
        unless @pseud
          raise ActiveRecord::RecordNotFound, "Couldn't find pseud '#{params[:pseud_id]}'"
        end
        @page_subtitle = ts("by ") + @pseud.byline
        pseuds = [@pseud]
      end
    end

    if current_user.nil?
      @series = Series.visible_to_all
    else
      @series = Series.visible_to_registered_user
    end
    if pseuds.present?
      @series = @series.exclude_anonymous.for_pseuds(pseuds)
    end
    @series = @series.paginate(page: params[:page])
  end

  # GET /series/1
  # GET /series/1.xml
  def show
    @serial_works = @series.serial_works.includes(:work).where('works.posted = ?', true).references(:works).order(:position).select{ |sw| sw.work.visible(User.current_user) }
    # sets the page title with the data for the series
    @page_title = @series.unrevealed? ? ts("Mystery Series") : get_page_title(@series.allfandoms.collect(&:name).join(', '), @series.anonymous? ? ts("Anonymous") : @series.allpseuds.collect(&:byline).join(', '), @series.title)
    if current_user.respond_to?(:subscriptions)
      @subscription = current_user.subscriptions.where(subscribable_id: @series.id,
                                                       subscribable_type: 'Series').first ||
                      current_user.subscriptions.build(subscribable: @series)
    end
  end

  # GET /series/new
  # GET /series/new.xml
  def new
    @series = Series.new
  end

 def load_pseuds
   @pseuds = current_user.pseuds
   @coauthors = @series.pseuds.reject { |p| p.user.id == current_user.id }
   to_select = @series.pseuds.blank? ? [current_user.default_pseud] : @series.pseuds
   @selected_pseuds = to_select.collect { |pseud| pseud.id.to_i }
   @allpseuds = (current_user.pseuds + (@series.authors ||= []) + @series.pseuds).uniq
 end

  # GET /series/1/edit
 def edit
   load_pseuds

   if params["remove"] == "me"
     pseuds_with_author_removed = @series.pseuds - current_user.pseuds
     if pseuds_with_author_removed.empty?
       redirect_to controller: 'orphans', action: 'new', series_id: @series.id
     else
       begin
         @series.remove_author(current_user)
         flash[:notice] = ts("You have been removed as an author from the series and its works.")
         redirect_to @series
       rescue Exception => error
         flash[:error] = error.message
         redirect_to @series
       end
     end
   end
 end

  # GET /series/1/manage
 def manage
   @serial_works = @series.serial_works.includes(:work).order(:position)
 end

  # POST /series
  # POST /series.xml
  def create
    @series = Series.new(series_params)
    if @series.save
      flash[:notice] = ts('Series was successfully created.')
      redirect_to(@series)
    else
      render action: "new"
    end
  end

  # Check whether we should display _choose_coauthor.
  def series_has_pseuds_to_fix?
    !(@series.invalid_pseuds.blank? &&
        @series.ambiguous_pseuds.blank?)
  end

  # PUT /series/1
  # PUT /series/1.xml
 def update
   load_pseuds

   if flash[:notice].present?
     # Issues found are promoted to errors and the series edited.
     flash[:error] = flash[:notice]
     flash[:notice] = ""
     redirect_to edit_series_path(@series) and return
   end

   if @series.update_attributes(series_params)
     # The duplicated if here does not work if you try and place it above.
     if series_has_pseuds_to_fix?
       render :_choose_coauthor and return
     end
     flash[:notice] = ts('Series was successfully updated.')
     redirect_to(@series)
   else
     if series_has_pseuds_to_fix?
       render :_choose_coauthor and return
     end
     render action: "edit"
   end
 end

  def update_positions
    if params[:serial_works]
      @series = Series.find(params[:id])
      @series.reorder(params[:serial_works])
      flash[:notice] = ts("Series order has been successfully updated.")
    elsif params[:serial]
      params[:serial].each_with_index do |id, position|
        SerialWork.update(id, position: position + 1)
        (@serial_works ||= []) << SerialWork.find(id)
      end
    end
    respond_to do |format|
      format.html { redirect_to(@series) and return }
      format.json { head :ok }
    end
  end

  # GET /series/1/confirm_delete
  def confirm_delete
  end

  # DELETE /series/1
  # DELETE /series/1.xml
  def destroy
    if @series.destroy
      flash[:notice] = ts("Series was successfully deleted.")
      redirect_to(current_user)
    else
      flash[:error] = ts("Sorry, we couldn't delete the series. Please try again.")
      redirect_to(@series)
    end
  end

  private

  def series_params
    params.require(:series).permit(
      :title, :summary, :series_notes, :complete,
      author_attributes: [:byline, ids: [], coauthors: [], ambiguous_pseuds: []]
    )
  end
end
