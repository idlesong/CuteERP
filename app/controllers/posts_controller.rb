class PostsController < ApplicationController
  # GET /posts
  # GET /posts.json
  def index


    if(params[:subject])
      @posts = Post.where("subject = ?", params[:subject]).order("title asc")
    else
      @posts = Post.order("title asc").all
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @posts }
    end
  end

  # GET /posts/1
  # GET /posts/1.json
  def show
    begin
      if(params[:query] == 'url')
        @post = Post.find_by_internal_url!(params[:id])
      else
        @post = Post.find(params[:id])
      end

    rescue ActiveRecord::RecordNotFound
      logger.error "Attempt to show invalid post #{params[:id]}"
      redirect_to new_post_path :internal_url => params[:id]
    else

      Post.order("title")
      @posts = Post.where("subject = ?", @post.subject).order("title asc")

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @post }
      end
    end
  end


  # GET /posts/new
  # GET /posts/new.json
  def new
    @post = Post.new

    if(params[:internal_url])
      @post.title = params[:internal_url]
      @post.internal_url = params[:internal_url]
    end

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @post }
    end
  end

  # GET /posts/1/edit
  def edit
    @post = Post.find(params[:id])
  end

  # POST /posts
  # POST /posts.json
  def create
    @post = Post.new(params[:post])

    respond_to do |format|
      if @post.save
        if params[:documents]
          params[:documents].each { |doc|
            @design.attachments.create(document: doc)
          }
        end

        format.html { redirect_to @post, notice: 'Post was successfully created.' }
        format.json { render json: @post, status: :created, location: @post }
      else
        format.html { render action: "new" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /posts/1
  # PUT /posts/1.json
  def update
    @post = Post.find(params[:id])

    respond_to do |format|
      if @post.update_attributes(params[:post])
        format.html { redirect_to @post, notice: 'Post was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /posts/1
  # DELETE /posts/1.json
  def destroy
    @post = Post.find(params[:id])
    @post.destroy

    respond_to do |format|
      format.html { redirect_to posts_url }
      format.json { head :no_content }
    end
  end
end
