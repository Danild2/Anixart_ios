import SwiftUI

struct ProfileBlogSection: View {
    let channel: ProfileChannel
    let own: Bool
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var model = ProfilePageState<ProfileArticle>()
    @State private var composer = false
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            Divider()
            HStack { Text("Блог").font(.headline); Spacer(); if own { Button { composer = true } label: { Label("Новая запись",systemImage:"square.and.pencil") } } }
            if let error = model.error { FailureNotice(message:error) { Task { await load(reset:false) } } }
            ForEach(model.items) { article in
                NavigationLink { ProfileArticleScreen(id:article.id) } label: { ProfileArticleCard(article:article,preview:true) }.buttonStyle(.plain)
                Divider()
            }
            if model.loading { ProgressView().frame(maxWidth:.infinity) }
            if model.items.isEmpty, !model.loading, model.error == nil { Text("Записей пока нет").foregroundStyle(.secondary).frame(maxWidth:.infinity,minHeight:80) }
            if !model.items.isEmpty, model.more, model.error == nil { Color.clear.frame(height:1).onAppear { Task { await load(reset:false) } } }
        }.padding(.horizontal,20).padding(.bottom,24).task(id:"\(channel.id)|\(session.identity)") { await load(reset:true) }
            .sheet(isPresented:$composer,onDismiss: { Task { await load(reset:true) } }) { NavigationStack { ProfileArticleComposer(channel:channel) } }
    }
    private func load(reset: Bool) async {
        let repository = repository, id = channel.id, token = session.token
        await model.load(reset:reset) { page in try await repository.blogArticles(id,page:page,token:token) }
    }
}
struct ProfileArticleCard: View {
    let article: ProfileArticle
    var preview = false
    var depth = 0
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack(spacing:10) {
                Poster(url:article.channel?.avatar.flatMap(URL.init(string:)),width:38,height:38).clipShape(Circle())
                VStack(alignment:.leading,spacing:3) {
                    Text(article.channel?.title ?? article.author?.login ?? "Запись").font(.subheadline.bold())
                    if let time = article.creationDate { Text(ProfileDate.text(time)).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if article.isPinned == true { Image(systemName:"pin.fill").font(.caption).foregroundStyle(.secondary) }
            }
            if article.isDeleted == true { Text("Запись удалена").foregroundStyle(.secondary) }
            else {
                ForEach(Array((preview ? Array((article.payload?.blocks ?? []).prefix(3)) : article.payload?.blocks ?? []).enumerated()),id:\.offset) { _, block in ProfileArticleBlockView(block:block) }
                if preview, (article.payload?.blocks?.count ?? 0) > 3 { Text("Читать далее").font(.subheadline).foregroundStyle(Color.accentColor) }
                if let repost = article.repostArticle, depth < 2 {
                    AnyView(ProfileArticleCard(article:repost.article,preview:preview,depth:depth + 1)).padding(12).background(.quaternary,in:RoundedRectangle(cornerRadius:16))
                }
            }
            HStack(spacing:24) {
                Label((article.voteCount ?? 0).formatted(),systemImage:"heart")
                Label((article.commentCount ?? 0).formatted(),systemImage:"bubble.right")
                Label((article.repostCount ?? 0).formatted(),systemImage:"arrowshape.turn.up.right")
            }.font(.footnote).foregroundStyle(.secondary)
        }
    }
}
struct ProfileArticleBlockView: View {
    let block: ArticleBlock
    var body: some View {
        switch block.type {
        case "paragraph": ArticleRichText(html:block.data["text"].string ?? "")
        case "header": ArticleRichText(html:block.data["text"].string ?? "").font(.title2.bold())
        case "quote":
            HStack(alignment:.top,spacing:12) {
                Rectangle().fill(Color.accentColor).frame(width:3)
                VStack(alignment:.leading,spacing:8) { ArticleRichText(html:block.data["text"].string ?? ""); if let caption = block.data["caption"].string, !caption.isEmpty { ArticleRichText(html:caption).font(.caption).foregroundStyle(.secondary) } }
            }.fixedSize(horizontal:false,vertical:true)
        case "delimiter": Text("• • •").font(.title3).frame(maxWidth:.infinity).foregroundStyle(.secondary)
        case "list":
            VStack(alignment:.leading,spacing:8) {
                ForEach(Array(block.data["items"].items.enumerated()),id:\.offset) { index, item in
                    HStack(alignment:.top) { Text(block.data["style"].string == "ordered" ? "\(index + 1)." : "•"); ArticleRichText(html:item.string ?? item["content"].string ?? "") }
                }
            }
        case "media":
            ForEach(Array(block.data["items"].items.enumerated()),id:\.offset) { _, item in
                if let raw = item["url"].string, let url = URL(string:raw) {
                    GeometryReader { g in Poster(url:url,width:g.size.width,height:g.size.height) }.aspectRatio(4/3,contentMode:.fit)
                }
            }
        case "embed":
            if let raw = block.data["url"].string, let url = URL(string:raw), ["https","http"].contains(url.scheme ?? "") {
                Link(destination:url) {
                    VStack(alignment:.leading,spacing:8) {
                        if let raw = block.data["image"].string, let image = URL(string:raw) { GeometryReader { g in Poster(url:image,width:g.size.width,height:g.size.height) }.aspectRatio(16/9,contentMode:.fit) }
                        Text(block.data["title"].string ?? url.host ?? raw).font(.headline)
                        if let description = block.data["description"].string { Text(description).font(.subheadline).foregroundStyle(.secondary) }
                        Text(block.data["siteName"].string ?? block.data["site_name"].string ?? url.host ?? "Открыть").font(.caption).foregroundStyle(.secondary)
                    }.padding(12).background(.quaternary,in:RoundedRectangle(cornerRadius:16))
                }
            }
        default:
            if let text = block.data["text"].string { ArticleRichText(html:text) }
            else { Text("Этот блок пока не поддерживается").font(.footnote).foregroundStyle(.secondary) }
        }
    }
}
struct ArticleRichText: View {
    let html: String
    private var text: AttributedString {
        guard let data = html.data(using:.utf8), let attributed = try? NSAttributedString(data:data,options:[.documentType:NSAttributedString.DocumentType.html,.characterEncoding:String.Encoding.utf8.rawValue],documentAttributes:nil) else { return AttributedString(html) }
        // Foundation attributes retain links and inline emphasis while SwiftUI
        // supplies the user's color scheme and Dynamic Type size.
        return AttributedString(attributed)
    }
    var body: some View { Text(text).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
}
struct ProfileArticleScreen: View {
    let id: Int64
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var article: ProfileArticle?
    @State private var error: String?
    var body: some View {
        ScrollView {
            if let article { ProfileArticleCard(article:article).padding(20) }
            else if let error { FailureNotice(message:error) { Task { await load() } } }
            else { ProgressView().padding() }
        }.navigationTitle("Запись").task { await load() }.refreshable { await load() }
    }
    private func load() async {
        error = nil
        do { let next = try await repository.article(id,token:session.token); try Task.checkCancellation(); article = next }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
struct ProfileArticleComposer: View {
    var channel: ProfileChannel?
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var busy = false
    @State private var error: String?
    @State private var createdChannel: ProfileChannel?
    var body: some View {
        Form {
            Section("Новая запись") { TextEditor(text:$text).frame(minHeight:220) }
            if let error { Text(error).foregroundStyle(.red) }
            if busy { ProgressView() }
        }.navigationTitle("Новая запись").toolbar {
            ToolbarItem(placement:.cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement:.confirmationAction) { Button("Опубликовать") { Task { await publish() } }.disabled(busy || text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
        }
    }
    private func publish() async {
        guard let token = session.token else { return }; busy = true; error = nil; defer { busy = false }
        struct Body: Encodable { let payload: String; let isSigned = false; let repostArticleId: Int64? = nil; enum CodingKeys: String,CodingKey { case payload; case isSigned = "is_signed"; case repostArticleId = "repost_article_id" } }
        let escaped = text.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"\n",with:"<br>")
        let payload = ArticlePayload(blocks:[ArticleBlock(id:UUID().uuidString,type:"paragraph",data:.object(["text":.text(escaped)]))],version:"2.31.0",time:Int64(Date().timeIntervalSince1970 * 1000))
        do {
            let encoded = try JSONEncoder().encode(payload)
            guard let json = String(data:encoded,encoding:.utf8) else { throw APIError.malformed }
            if channel == nil && createdChannel == nil {
                let result: ProfileChannelResponse = try await repository.client.request(Endpoint(path:"channel/blog/create",method:"POST",isReadOnly:false),token:token)
                guard let created = result.channel else { throw APIError.malformed }; createdChannel = created
            }
            guard let target = channel ?? createdChannel else { throw APIError.malformed }
            let _: Acknowledgement = try await repository.client.request(Endpoint(path:"article/create/\(target.id)",method:"POST",body:JSONEncoder().encode(Body(payload:json)),isReadOnly:false),token:token)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
