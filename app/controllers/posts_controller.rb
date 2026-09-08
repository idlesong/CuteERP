class PostsController < ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  # GET /posts
  def index
    if params[:subject]
      @posts = Post.where("subject = ?", params[:subject]).order("title asc")
    else
      @posts = Post.order("title asc").all
    end

    respond_to do |format|
      format.html
      format.json { render json: @posts }
    end
  end

  # GET /posts/1
  def show
    @posts = Post.where("subject = ?", @post.subject).order("title asc")

    respond_to do |format|
      format.html
      format.json { render json: @post }
    end
  end

  # GET /posts/new
  def new
    @post = Post.new

    if params[:internal_url]
      @post.title = params[:internal_url]
      @post.internal_url = params[:internal_url]
    end

    respond_to do |format|
      format.html
      format.json { render json: @post }
    end
  end

  # GET /posts/1/edit
  def edit
  end

  # POST /posts
  def create
    @post = Post.new(post_params)

    respond_to do |format|
      if @post.save
        if params[:documents]
          params[:documents].each do |doc|
            attachment = @post.attachments.create(name: doc.original_filename)
            attachment.document.attach(doc)
          end
        end

        format.html { redirect_to @post, notice: "Post was successfully created." }
        format.json { render json: @post, status: :created, location: @post }
      else
        format.html { render action: "new" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /posts/1
  def update
    respond_to do |format|
      if @post.update(post_params)
        format.html { redirect_to @post, notice: "Post was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /posts/1
  def destroy
    @post.destroy

    respond_to do |format|
      format.html { redirect_to posts_url }
      format.json { head :no_content }
    end
  end

  private

  def set_post
    if params[:query] == "url"
      @post = Post.find_by_internal_url!(params[:id])
    else
      @post = Post.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    logger.error "Attempt to show invalid post #{params[:id]}"
    redirect_to new_post_path(internal_url: params[:id])
  end

  def post_params
    params.require(:post).permit(:content, :subject, :title, :internal_url)
  end
end
