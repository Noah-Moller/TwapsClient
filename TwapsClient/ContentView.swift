import SwiftUI
import Foundation
import AppKit

// MARK: - DynamicViewModel

/// A view model that manages the dynamic content loaded from Twaps.
class DynamicViewModel: ObservableObject {
    @Published var dynamicContent: AnyView? = nil
    @Published var windowID: String = "dynamic" // initial id
    static let shared = DynamicViewModel()
    
    func updateContent(_ newContent: AnyView) {
        Task { @MainActor in
            self.dynamicContent = newContent
            // Generate a new unique id so that openWindow creates a new window.
            self.windowID = "dynamic-\(UUID().uuidString)"
        }
    }
}

// MARK: - Plugin Compilation and Loading

/// Compile a Swift source file into a dynamic library.
/// If compile errors are detected (via "error:" in the output),
/// it sends the original source and error output to OpenRouter to fix the code,
/// and then recursively attempts to compile the returned code.
func compilePlugin(from source: String, APIKey: String) async -> (success: Bool, outputPath: String) {
    let uniqueName = "Plugin_\(UUID().uuidString).dylib"
    let outputPath = "/tmp/" + uniqueName
    let tempSourcePath = "/tmp/Plugin.swift"
    
    do {
        try source.write(toFile: tempSourcePath, atomically: true, encoding: .utf8)
    } catch {
        print("Error writing source file: \(error)")
        return (false, outputPath)
    }
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
    process.arguments = [
        "-Onone",
        "-emit-library",
        "-o", outputPath,
        tempSourcePath,
        "-module-name", "Plugin",
        "-Xlinker", "-export_dynamic"
    ]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        print("Compiler output:\n\(output)")
        
        // If there is a compile error, try to fix the code via OpenRouter.
        if output.contains("error:") {
            guard let url = URL(string: "\(OpenRouterConfig.baseURL)/chat/completions") else {
                print("Invalid OpenRouter URL")
                return (false, outputPath)
            }
            
            let messages = [
                Message(role: "system", content: #"""
            Your job is to be a model that outputs SwiftUI code for MacOS based on a user prompt. You can expect users to ask to make a tool, your job is to make that in SwiftUI or if need appkit. Your output should always just contain code and not any other text. Your views aren't going to be traditional view however below is the way you should output your SwiftUI views. Your output should just work as expected and should need no further adjustments. Also do not ever use markdown formatting in your response!!!

            Swift UI view example:

            import SwiftUI
            import AppKit

            @_cdecl("createDynamicView")
            public func createDynamicView() -> UnsafeMutableRawPointer {
                let view = AnyView(
                    VStack {
                        Text("Hello from my first Twap!")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        Button("Click Me") {
                            print("Button clicked!")
                            let alert = NSAlert()
                            alert.messageText = "Hello!"
                            alert.informativeText = "This is my first Twap!"
                            alert.runModal()
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .frame(width: 400, height: 300)
                )
                let hostingController = NSHostingController(rootView: view)
                return Unmanaged.passRetained(hostingController).toOpaque()
            }

            public let __forceExport_createDynamicView: Void = {
                _ = createDynamicView
            }()
            
                            Guide:

                            Best Practices for macOS SwiftUI Development

                            Developing a SwiftUI app for macOS requires a slightly different mindset than for iOS. Here are some best practices and tips to create a great Mac experience:
                                •    Follow Mac Conventions: Use the menu bar and toolbar appropriately. Ensure every important action is available in a menu (with a keyboard shortcut) ￼ – Mac power users expect this. Also implement the standard macOS shortcuts where appropriate (⌘+N for new document/window, ⌘+O for open, ⌘+S for save, etc., if those actions make sense in your app).
                                •    Use Platform-Specific UI When Appropriate: SwiftUI is multiplatform, but don’t force an iPad-style UI on Mac. Take advantage of split views, sidebars (NavigationSplitView), and resizable layouts which are common on desktop. For example, use List with multiple columns or the new Table view for tabular data instead of a simplistic iPhone-style list ￼. Also consider using popovers or separate windows instead of modal sheets for Mac, as modality is less common on desktop (except dialogs).
                                •    Enable Keyboard Navigation: Test your app with just the keyboard. Can the user tab through controls and activate them? If not, consider where you might need .focusable() or FocusState. Mac users can turn on full keyboard access to navigate all controls (Tab key navigation) – your app should handle this gracefully (e.g., the highlight ring should move logically). Implement default and cancel actions for dialogs as discussed, and add keyboard shortcuts (via .keyboardShortcut) for any frequently used button.
                                •    Incorporate Drag and Drop: If your app deals with content that could be dragged (text, images, files), implement drag-and-drop using SwiftUI’s modifiers. On Mac, users will try to drag things between windows or out to Finder, etc. Even if your iOS app didn’t need it, on macOS it can greatly improve user experience.
                                •    Leverage Settings Scene: If your app has preferences, use Settings in SwiftUI to automatically get a standard Preferences window with the correct sizing and title. Within your Settings view, you can layout form-style controls (Toggle, Sliders, pickers) just like in iOS Settings, but it will appear in a Mac preferences panel.
                                •    Use AppKit When Needed, Thoughtfully: Don’t be afraid to use NSViewRepresentable to fill gaps (like an NSTextView for rich text editing or an NSProgressIndicator if you want that exact look). As another example, if you want a custom cursor or to handle scroll wheel events in a special way, an AppKit NSView could help. Using AppKit for a small piece doesn’t diminish your SwiftUI app – it enhances it ￼. Just keep the integration well-encapsulated (as in the ColorWell example).
                                •    Optimize for macOS Performance: SwiftUI on macOS is still young, and very large or complex views (like huge lists) might have performance issues ￼. If you encounter sluggishness with a List of thousands of items, you might need to simplify the view or use an AppKit optimized component. Test performance and memory with multiple windows open.
                                •    Test on Different Window Sizes: Users can resize windows to very large or very small. Make sure your SwiftUI layouts adapt (use flexible frames, spacers, GeometryReader if needed) to handle resizing without breaking the UI. Also, test light vs dark mode, and if your app supports it, different accent colors or high contrast settings.
                                •    Consider Accessibility and Input Modes: macOS might have the user on a mouse, trackpad, or using VoiceOver. SwiftUI generally inherits good accessibility from controls, but ensure your custom views have accessibility labels. Also, if your app might be used with an Apple Pencil on iPad (through Mac Catalyst or Sidecar), that’s fringe but something to consider if applicable.
                                •    Stay Updated with SwiftUI Improvements: Each macOS release brings SwiftUI enhancements. For instance, macOS 14 improved focus handling for custom views, and introduced new modifiers. WWDC sessions often cover “what’s new in SwiftUI for macOS.” Utilizing newer APIs (like .openWindow introduced in macOS 13, or .alert improvements, etc.) can simplify your code.

                            By adhering to these best practices, your SwiftUI-based Mac app will feel at home on the platform and provide the polished experience users expect.
            """#),
                Message(role: "user", content: """
                The following is some code that failed to compile along side the error messages. Your job is to fix these errors:
                
                Code:
                \(source)
                
                Compile output:
                \(output)
                """)
            ]
            
            let requestBody = ChatCompletionRequest(
                model: "openai/gpt-4o",
                messages: messages
            )
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(APIKey)", forHTTPHeaderField: "Authorization")
            
            do {
                let jsonData = try JSONEncoder().encode(requestBody)
                request.httpBody = jsonData
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        let decodedResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                        if let fixedCode = decodedResponse.choices.first?.message.content {
                            // Recursively try to compile the fixed code.
                            return await compilePlugin(from: fixedCode, APIKey: APIKey)
                        } else {
                            print("No fixed code returned from OpenRouter.")
                            return (false, outputPath)
                        }
                    } else {
                        print("Error: HTTP \(httpResponse.statusCode)")
                        return (false, outputPath)
                    }
                } else {
                    print("Unexpected response.")
                    return (false, outputPath)
                }
            } catch {
                print("Error during OpenRouter request: \(error.localizedDescription)")
                return (false, outputPath)
            }
        }
        return (process.terminationStatus == 0, outputPath)
    } catch {
        print("Error running swiftc: \(error)")
        return (false, outputPath)
    }
}

/// Type definition for the createDynamicView function exported by the dynamic library.
typealias CreateDynamicViewFunc = @convention(c) () -> UnsafeMutableRawPointer

/// Load a dynamic view from a compiled library.
@MainActor
func loadDynamicView(from libraryPath: String) -> NSHostingController<AnyView>? {
    guard let handle = dlopen(libraryPath, RTLD_NOW) else {
        if let err = dlerror() {
            print("dlopen error: \(String(cString: err))")
        }
        return nil
    }
    
    dlerror() // Clear any existing error.
    
    guard let sym = dlsym(handle, "createDynamicView") else {
        if let err = dlerror() {
            print("dlsym error: \(String(cString: err))")
        }
        dlclose(handle)
        return nil
    }
    
    let function = unsafeBitCast(sym, to: CreateDynamicViewFunc.self)
    let rawPtr = function()  // Called on the main thread.
    let unmanaged = Unmanaged<NSHostingController<AnyView>>.fromOpaque(rawPtr)
    let hostingController = unmanaged.takeRetainedValue()
    return hostingController
}

// MARK: - OpenRouter API and Message Types

struct OpenRouterConfig {
    static let baseURL = "https://openrouter.ai/api/v1"
}

struct Message: Codable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [Message]
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.openWindow) var openWindow
    @EnvironmentObject var dynamicViewModel: DynamicViewModel
    @State private var twapURL: String = ""
    @State private var errorMessage: String?
    @State private var userPrompt: String = ""
    @State private var aiResponse: String = ""
    @State private var APIKey: String = ""
    @State private var showProgressView = false
    
    var body: some View {
        HStack(spacing: 20) {
            // Left panel for Twap URL
            VStack(spacing: 15) {
                Text("Enter your Twap URL")
                    .font(.headline)
                TextField("Twap URL", text: $twapURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Go") {
                    Task {
                        await fetchAndLoadTwap()
                    }
                }
                if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
                Spacer()
            }
            .padding()
            .frame(minWidth: 300)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
            
            // Right panel for AI chat
            VStack(spacing: 15) {
                Text("Have an idea? Let's build it!")
                    .font(.headline)
                SecureField("Enter your OpenRouter API key", text: $APIKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Enter your prompt", text: $userPrompt)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Build") {
                    showProgressView = true
                    Task {
                        await sendToOpenRouter()
                    }
                }
                Spacer()
                if showProgressView {
                    ProgressView()
                }
            }
            .padding()
            .frame(minWidth: 300)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
        }
        .padding()
        .frame(minWidth: 700, minHeight: 400)
        // When aiResponse updates, compile and load the dynamic view.
        .onChange(of: aiResponse) { oldValue, newValue in
            showProgressView = false
            Task {
                let result = await compilePlugin(from: newValue, APIKey: APIKey)
                if result.success {
                    await MainActor.run {
                        if let vc = loadDynamicView(from: result.outputPath) {
                            dynamicViewModel.dynamicContent = vc.rootView
                        } else {
                            errorMessage = "Failed to load dynamic view."
                        }
                    }
                    // Close any existing dynamic windows.
                    await MainActor.run {
                        for window in NSApplication.shared.windows {
                            if window.title == "Dynamic View" {
                                window.close()
                            }
                        }
                    }
                    // Open the dynamic window.
                    openWindow(id: "dynamic")
                } else {
                    await MainActor.run {
                        errorMessage = "Failed to compile plugin."
                    }
                }
            }
        }
    }
    
    /// Fetch the Twap source code and load the dynamic view.
    func fetchAndLoadTwap() async {
        let source = fetchData(twapURL: twapURL)
        let result = await compilePlugin(from: source, APIKey: APIKey)
        if result.success {
            await MainActor.run {
                if let vc = loadDynamicView(from: result.outputPath) {
                    dynamicViewModel.dynamicContent = vc.rootView
                } else {
                    errorMessage = "Failed to load dynamic view."
                }
            }
            await MainActor.run {
                for window in NSApplication.shared.windows {
                    if window.title == "Dynamic View" {
                        window.close()
                    }
                }
            }
            openWindow(id: "dynamic")
        } else {
            await MainActor.run {
                errorMessage = "No Twap found at \(twapURL)."
            }
        }
    }
    
    /// Fetch Twap source code from the server.
    func fetchData(twapURL: String) -> String {
        var returnedTwap = ""
        guard let url = URL(string: "http://localhost:8080/twap") else {
            fatalError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = twapURL.data(using: .utf8)
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Networking error: \(error)")
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
            }
            if let data = data,
               let responseString = String(data: data, encoding: .utf8) {
                print("Response body: \(responseString)")
                returnedTwap = responseString
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        return returnedTwap
    }
    
    /// Send a prompt to OpenRouter.
    func sendToOpenRouter() async {
        guard let url = URL(string: "\(OpenRouterConfig.baseURL)/chat/completions") else {
            await MainActor.run {
                errorMessage = "Invalid OpenRouter URL"
            }
            return
        }
        let messages = [
            Message(role: "system", content: #"""
            Your job is to be a model that outputs SwiftUI code for MacOS based on a user prompt. You can expect users to ask to make a tool, your job is to make that in SwiftUI or if need appkit. Your output should always just contain code and not any other text. Your views aren't going to be traditional view however below is the way you should output your SwiftUI views. Your output should just work as expected and should need no further adjustments. Also do not ever use markdown formatting in your response!!!

            Swift UI view example:

            import SwiftUI
            import AppKit

            @_cdecl("createDynamicView")
            public func createDynamicView() -> UnsafeMutableRawPointer {
                let view = AnyView(
                    VStack {
                        Text("Hello from my first Twap!")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        Button("Click Me") {
                            print("Button clicked!")
                            let alert = NSAlert()
                            alert.messageText = "Hello!"
                            alert.informativeText = "This is my first Twap!"
                            alert.runModal()
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .frame(width: 400, height: 300)
                )
                let hostingController = NSHostingController(rootView: view)
                return Unmanaged.passRetained(hostingController).toOpaque()
            }

            public let __forceExport_createDynamicView: Void = {
                _ = createDynamicView
            }()
            
                            Guide:

                            Best Practices for macOS SwiftUI Development

                            Developing a SwiftUI app for macOS requires a slightly different mindset than for iOS. Here are some best practices and tips to create a great Mac experience:
                                •    Follow Mac Conventions: Use the menu bar and toolbar appropriately. Ensure every important action is available in a menu (with a keyboard shortcut) ￼ – Mac power users expect this. Also implement the standard macOS shortcuts where appropriate (⌘+N for new document/window, ⌘+O for open, ⌘+S for save, etc., if those actions make sense in your app).
                                •    Use Platform-Specific UI When Appropriate: SwiftUI is multiplatform, but don’t force an iPad-style UI on Mac. Take advantage of split views, sidebars (NavigationSplitView), and resizable layouts which are common on desktop. For example, use List with multiple columns or the new Table view for tabular data instead of a simplistic iPhone-style list ￼. Also consider using popovers or separate windows instead of modal sheets for Mac, as modality is less common on desktop (except dialogs).
                                •    Enable Keyboard Navigation: Test your app with just the keyboard. Can the user tab through controls and activate them? If not, consider where you might need .focusable() or FocusState. Mac users can turn on full keyboard access to navigate all controls (Tab key navigation) – your app should handle this gracefully (e.g., the highlight ring should move logically). Implement default and cancel actions for dialogs as discussed, and add keyboard shortcuts (via .keyboardShortcut) for any frequently used button.
                                •    Incorporate Drag and Drop: If your app deals with content that could be dragged (text, images, files), implement drag-and-drop using SwiftUI’s modifiers. On Mac, users will try to drag things between windows or out to Finder, etc. Even if your iOS app didn’t need it, on macOS it can greatly improve user experience.
                                •    Leverage Settings Scene: If your app has preferences, use Settings in SwiftUI to automatically get a standard Preferences window with the correct sizing and title. Within your Settings view, you can layout form-style controls (Toggle, Sliders, pickers) just like in iOS Settings, but it will appear in a Mac preferences panel.
                                •    Use AppKit When Needed, Thoughtfully: Don’t be afraid to use NSViewRepresentable to fill gaps (like an NSTextView for rich text editing or an NSProgressIndicator if you want that exact look). As another example, if you want a custom cursor or to handle scroll wheel events in a special way, an AppKit NSView could help. Using AppKit for a small piece doesn’t diminish your SwiftUI app – it enhances it ￼. Just keep the integration well-encapsulated (as in the ColorWell example).
                                •    Optimize for macOS Performance: SwiftUI on macOS is still young, and very large or complex views (like huge lists) might have performance issues ￼. If you encounter sluggishness with a List of thousands of items, you might need to simplify the view or use an AppKit optimized component. Test performance and memory with multiple windows open.
                                •    Test on Different Window Sizes: Users can resize windows to very large or very small. Make sure your SwiftUI layouts adapt (use flexible frames, spacers, GeometryReader if needed) to handle resizing without breaking the UI. Also, test light vs dark mode, and if your app supports it, different accent colors or high contrast settings.
                                •    Consider Accessibility and Input Modes: macOS might have the user on a mouse, trackpad, or using VoiceOver. SwiftUI generally inherits good accessibility from controls, but ensure your custom views have accessibility labels. Also, if your app might be used with an Apple Pencil on iPad (through Mac Catalyst or Sidecar), that’s fringe but something to consider if applicable.
                                •    Stay Updated with SwiftUI Improvements: Each macOS release brings SwiftUI enhancements. For instance, macOS 14 improved focus handling for custom views, and introduced new modifiers. WWDC sessions often cover “what’s new in SwiftUI for macOS.” Utilizing newer APIs (like .openWindow introduced in macOS 13, or .alert improvements, etc.) can simplify your code.

                            By adhering to these best practices, your SwiftUI-based Mac app will feel at home on the platform and provide the polished experience users expect.
            """#),
            Message(role: "user", content: userPrompt)
        ]
        
        let requestBody = ChatCompletionRequest(
            model: "openai/gpt-4o",
            messages: messages
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(APIKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let decodedResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                    if let content = decodedResponse.choices.first?.message.content {
                        await MainActor.run {
                            aiResponse = content
                            errorMessage = nil
                        }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Dynamic Content View

/// A view that displays the dynamically loaded content.
struct DynamicContentView: View {
    @EnvironmentObject var dynamicViewModel: DynamicViewModel
    var body: some View {
        if let dynamicContent = dynamicViewModel.dynamicContent {
            dynamicContent
        } else {
            Text("No dynamic view loaded.")
        }
    }
}
