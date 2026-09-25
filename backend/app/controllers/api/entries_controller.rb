class Api::EntriesController < Api::BaseController
  def index
    search = EntrySearch.new(**params.permit(:month, :category_id, :keyword, :from, :to).to_h.symbolize_keys)
    raise_bad_request(search) unless search.valid?

    # 1 件多く取って超過を判定する。先頭 1,000 件だけを返す「打ち切り」にはしない（docs/features.md F-08）
    entries = search.entries.limit(EntrySearch::LIMIT + 1).to_a
    raise Api::BadRequest, "期間が広すぎます。1,000件を超えるため、期間を絞ってください" if entries.size > EntrySearch::LIMIT

    @entries = entries
  end
end
