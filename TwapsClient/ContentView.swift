import SwiftUI
import Foundation
import AppKit

/**
 * DynamicViewModel
 *
 * A view model that manages the dynamic content loaded from Twaps.
 * This class is responsible for:
 * - Storing the current dynamic content (the loaded Twap)
 * - Generating unique window IDs for each new Twap
 * - Notifying the UI when the content changes
 */
class DynamicViewModel: ObservableObject {
    /// The current dynamic content (the loaded Twap)
    @Published var dynamicContent: AnyView? = nil
    
    /// A unique ID for the window that displays the dynamic content
    @Published var windowID: String = "dynamic" // initial id
    
    /**
     * Update the dynamic content
     *
     * This method:
     * 1. Updates the dynamic content with the new view
     * 2. Generates a new unique window ID
     *
     * - Parameter newContent: The new view to display
     */
    func updateContent(_ newContent: AnyView) {
        dynamicContent = newContent
        // Generate a new unique id so that openWindow creates a new window.
        windowID = "dynamic-\(UUID().uuidString)"
    }
}

/**
 * Compile a Swift source file into a dynamic library
 *
 * This function:
 * 1. Creates a temporary Swift source file
 * 2. Compiles it into a dynamic library using swiftc
 * 3. Returns the success status and the path to the compiled library
 *
 * - Parameter source: The Swift source code to compile
 * - Returns: A tuple containing the success status and the path to the compiled library
 */
func compilePlugin(from source: String) -> (success: Bool, outputPath: String) {
    // Create a unique output path for each compilation.
    let uniqueName = "Plugin_\(UUID().uuidString).dylib"
    let outputPath = "/tmp/" + uniqueName
    let tempSourcePath = "/tmp/Plugin.swift"
    
    // Write the source code to a temporary file
    do {
        try source.write(toFile: tempSourcePath, atomically: true, encoding: .utf8)
    } catch {
        print("Error writing source file: \(error)")
        return (false, outputPath)
    }
    
    // Set up the Swift compiler process
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
    process.arguments = [
        "-Onone",                           // Disable optimizations for debugging
        "-emit-library",                    // Create a dynamic library
        "-o", outputPath,                   // Output path
        tempSourcePath,                     // Input path
        "-module-name", "Plugin",           // Module name
        "-Xlinker", "-export_dynamic"       // Export symbols dynamically
    ]
    
    // Capture the compiler output
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    // Run the compiler
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            print("Compiler output:\n\(output)")
        }
        return (process.terminationStatus == 0, outputPath)
    } catch {
        print("Error running swiftc: \(error)")
        return (false, outputPath)
    }
}

/// Type definition for the createDynamicView function exported by the dynamic library
typealias CreateDynamicViewFunc = @convention(c) () -> UnsafeMutableRawPointer

/**
 * Load a dynamic view from a compiled library
 *
 * This function:
 * 1. Opens the dynamic library
 * 2. Looks up the createDynamicView symbol
 * 3. Calls the function to create the view
 * 4. Returns the hosting controller containing the view
 *
 * - Parameter libraryPath: The path to the compiled library
 * - Returns: An NSHostingController containing the dynamic view, or nil if loading fails
 */
func loadDynamicView(from libraryPath: String) -> NSHostingController<AnyView>? {
    // Open the dynamic library
    guard let handle = dlopen(libraryPath, RTLD_NOW) else {
        if let err = dlerror() {
            print("dlopen error: \(String(cString: err))")
        }
        return nil
    }
    
    // Clear any previous error
    dlerror()
    
    // Look up the createDynamicView symbol
    guard let sym = dlsym(handle, "createDynamicView") else {
        if let err = dlerror() {
            print("dlsym error: \(String(cString: err))")
        }
        dlclose(handle)
        return nil
    }
    
    // Cast the symbol to a function pointer and call it
    let function = unsafeBitCast(sym, to: CreateDynamicViewFunc.self)
    let rawPtr = function()
    
    // Convert the raw pointer to an NSHostingController
    let unmanaged = Unmanaged<NSHostingController<AnyView>>.fromOpaque(rawPtr)
    let hostingController = unmanaged.takeRetainedValue()
    return hostingController
}

/**
 * ContentView
 *
 * The main view of the TwapsClient app.
 * This view allows users to:
 * 1. Enter a Twap URL
 * 2. Fetch the Twap from the server
 * 3. Compile and load the Twap
 * 4. Display the Twap in a new window
 */
struct ContentView: View {
    // Use SwiftUI's openWindow environment key to open new windows
    @Environment(\.openWindow) var openWindow
    
    // The dynamic view model that manages the loaded Twap
    @EnvironmentObject var dynamicViewModel: DynamicViewModel
    
    // The URL of the Twap to load
    @State private var twapURL: String = ""
    
    // An error message to display if loading fails
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter your twap URL")
                .font(.headline)
            
            TextField("Twap URL", text: $twapURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button("Go") {
                // Fetch the Twap source code from the server
                let source = fetchData(twapURL: twapURL)
                
                // Compile the Twap source code into a dynamic library
                let result = compilePlugin(from: source)
                
                if result.success {
                    // Clear any previous error message
                    errorMessage = nil
                    
                    // Load the dynamic view from the compiled library
                    if let vc = loadDynamicView(from: result.outputPath) {
                        // Update the dynamic view model with the new view
                        dynamicViewModel.dynamicContent = vc.rootView
                        
                        // Close any existing dynamic view windows
                        for window in NSApplication.shared.windows {
                            if window.title == "Dynamic View" {
                                window.close()
                            }
                        }
                        
                        // Open a new window to display the dynamic view
                        openWindow(id: "dynamic")
                    } else {
                        errorMessage = "Failed to load dynamic view."
                    }
                } else {
                    errorMessage = "No Twap found at \(twapURL)."
                }
            }
            
            // Display an error message if loading fails
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
    }
    
    /**
     * Fetch Twap source code from the server
     *
     * This method:
     * 1. Creates a POST request to the server with the Twap URL
     * 2. Waits for the response synchronously
     * 3. Returns the Twap source code
     *
     * - Parameter twapURL: The URL of the Twap to fetch
     * - Returns: The Twap source code
     */
    func fetchData(twapURL: String) -> String {
        var returnedTwap = ""
        
        // Create a URL for the server endpoint
        guard let url = URL(string: "http://localhost:8080/twap") else {
            fatalError("Invalid URL")
        }
        
        // Create a POST request with the Twap URL in the body
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("text/plain", forHTTPHeaderField: "Content-Type")
        let rawString = twapURL
        request.httpBody = rawString.data(using: .utf8)
        
        // Create a semaphore to wait for the response
        let semaphore = DispatchSemaphore(value: 0)
        
        // Send the request
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
}
