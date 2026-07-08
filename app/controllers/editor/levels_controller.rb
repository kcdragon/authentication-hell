class Editor::LevelsController < Editor::ApplicationController
  def index
    render json: {
      levels: Editor::LevelFile.all.map do |level|
        { slug: level.slug, title: level.title, draft: level.draft? }
      end,
      next_slug: Editor::LevelFile.next_slug
    }
  end

  def show
    level = Editor::LevelFile.find(params[:slug])
    return head :not_found unless level

    render json: level.data
  end

  def create
    level = Editor::LevelFile.new(level_params.to_h)
    if level.valid?
      level.write
      render json: { ok: true, slug: level.slug, draft: level.draft? }
    else
      render json: { ok: false, errors: level.errors }, status: :unprocessable_entity
    end
  end

  def promote
    level = Editor::LevelFile.find(params[:slug])
    return head :not_found unless level

    if level.draft?
      level.promote!
      render json: { ok: true, slug: level.slug }
    else
      render json: { ok: false, errors: [ "already in the game" ] }, status: :unprocessable_entity
    end
  end

  private

  def level_params
    params.permit(:format, :slug, :title, :accent, :world_w, :start_x, :start_y, :time_limit,
                  :certificate_x,
                  platforms: %i[ x y w ], holes: %i[ x w ], enemies: %i[ kind x ])
  end
end
