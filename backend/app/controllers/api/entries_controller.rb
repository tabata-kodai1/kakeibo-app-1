class Api::EntriesController < Api::BaseController
  ENTRY_FIELDS = %i[entry_date category_id amount memo].freeze

  def index
    search = EntrySearch.new(**params.permit(:month, :category_id, :keyword, :from, :to).to_h.symbolize_keys)
    raise_bad_request(search) unless search.valid?

    # 1 件多く取って超過を判定する。先頭 1,000 件だけを返す「打ち切り」にはしない（docs/features.md F-08）
    entries = search.entries.limit(EntrySearch::LIMIT + 1).to_a
    raise Api::BadRequest, "期間が広すぎます。1,000件を超えるため、期間を絞ってください" if entries.size > EntrySearch::LIMIT

    @entries = entries
  end

  def create
    @entry = Entry.new(entry_params)
    raise_bad_request(@entry) unless @entry.save

    render :show, status: :created
  end

  # 4 項目すべてを置き換える。省略した項目は未入力になる（memo は null、それ以外は 400）。
  # ID の存在確認が先なので、存在しない ID には不正な値を送っても 404 になる
  def update
    @entry = Entry.find(params[:id])
    @entry.assign_attributes(ENTRY_FIELDS.index_with(nil).merge(entry_params.to_h.symbolize_keys))
    raise_bad_request(@entry) unless @entry.save

    render :show
  end

  def destroy
    Entry.find(params[:id]).destroy!

    head :no_content
  end

  private

  # ハッシュや配列で送られた値は permit で落ちるため、モデルには届かず未入力と同じ扱いになる。
  # id や created_at など、ここに挙げていない項目は無視される
  def entry_params
    params.permit(*ENTRY_FIELDS)
  end
end
