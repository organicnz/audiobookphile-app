import sys

path = "Sources/Audiobookphile/Views/AudioPlayerView.swift"
with open(path, "r") as f:
    content = f.read()

# Add isUiLocked state
if "@State var isUiLocked = false" not in content:
    content = content.replace("@State var draggedTime: TimeInterval = 0", "@State var draggedTime: TimeInterval = 0\n    @State var isUiLocked = false\n    @State var showBookmarksList = false\n    @State var showAddBookmark = false\n    @State var newBookmarkTitle = \"\"")

# Add lock button to top bar
top_bar_old = """    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }

            Spacer()

            Button {
                showMoreMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }
        }
        .padding(.horizontal, 24)
    }"""
top_bar_new = """    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }

            Spacer()
            
            Button {
                withAnimation {
                    isUiLocked.toggle()
                }
            } label: {
                Image(systemName: isUiLocked ? "lock.fill" : "lock.open")
                    .font(.title2)
                    .foregroundStyle(isUiLocked ? Color.appPrimary : (coverIsLight ? .black : .white))
            }
            .padding(.trailing, 16)

            Button {
                showMoreMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }
        }
        .padding(.horizontal, 24)
    }"""
content = content.replace(top_bar_old, top_bar_new)

# Disable skip buttons if locked
playback_controls_old = """            GlassIconButton(
                icon: "gobackward.\\(viewModel.jumpBackwardTime)",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpBackward
            )"""
playback_controls_new = """            GlassIconButton(
                icon: "gobackward.\\(viewModel.jumpBackwardTime)",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpBackward
            )
            .disabled(isUiLocked)
            .opacity(isUiLocked ? 0.3 : 1.0)"""
content = content.replace(playback_controls_old, playback_controls_new)

playback_controls_forward_old = """            GlassIconButton(
                icon: "goforward.\\(viewModel.jumpForwardTime)",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpForward
            )"""
playback_controls_forward_new = """            GlassIconButton(
                icon: "goforward.\\(viewModel.jumpForwardTime)",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpForward
            )
            .disabled(isUiLocked)
            .opacity(isUiLocked ? 0.3 : 1.0)"""
content = content.replace(playback_controls_forward_old, playback_controls_forward_new)

# Disable dragging if locked
drag_gesture_old = """                .gesture(
                    DragGesture(minimumDistance: 0)"""
drag_gesture_new = """                .gesture(
                    isUiLocked ? nil : DragGesture(minimumDistance: 0)"""
content = content.replace(drag_gesture_old, drag_gesture_new)

# Bookmark logic
bookmark_button_old = """            GlassIconButton(
                icon: "bookmark",
                fill: viewModel.hasBookmarks,
                color: coverIsLight ? .black : .white,
                action: viewModel.showBookmarks
            )"""
bookmark_button_new = """            Menu {
                Button {
                    showAddBookmark = true
                } label: {
                    Label("Add Bookmark", systemImage: "plus")
                }
                Button {
                    showBookmarksList = true
                } label: {
                    Label("View Bookmarks", systemImage: "list.bullet")
                }
            } label: {
                Image(systemName: viewModel.hasBookmarks ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }"""
content = content.replace(bookmark_button_old, bookmark_button_new)

# Add sheets to bottom
sheets_old = """        .sheet(isPresented: $showChapters) {"""
sheets_new = """        .alert("Add Bookmark", isPresented: $showAddBookmark) {
            TextField("Bookmark Title (Optional)", text: $newBookmarkTitle)
            Button("Cancel", role: .cancel) {
                newBookmarkTitle = ""
            }
            Button("Save") {
                viewModel.addBookmark(title: newBookmarkTitle)
                newBookmarkTitle = ""
            }
        }
        .sheet(isPresented: $showBookmarksList) {
            BookmarksListView(viewModel: viewModel)
        }
        .sheet(isPresented: $showChapters) {"""
content = content.replace(sheets_old, sheets_new)

with open(path, "w") as f:
    f.write(content)
