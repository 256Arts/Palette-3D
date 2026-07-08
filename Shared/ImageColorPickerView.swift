//
//  ImageColorPickerView.swift
//  Palette 3D
//
//  An eyedropper sheet: displays an image and lets the user drag a magnifier loupe over it to
//  sample a pixel color. Also houses the cross-platform image loading helpers and (on iOS) the
//  camera capture controller used by AddColorView's image sources.
//

import SwiftUI
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if os(iOS)
import AVFoundation
#endif

// MARK: - Pixel sampling

/// Decodes a `CGImage` once into a Display P3 RGBA8 buffer so individual pixels can be sampled cheaply.
private final class ImagePixelSampler {

    let width: Int
    let height: Int
    private let pixels: [UInt8]

    init?(cgImage: CGImage) {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        // Sample in Display P3 to preserve wide-gamut colors, matching the rest of the app's pipeline.
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let context = buffer.withUnsafeMutableBytes({ raw in
                  CGContext(
                    data: raw.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
              }) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.width = width
        self.height = height
        self.pixels = buffer
    }

    /// Samples the color at a point given in normalized image coordinates (origin top-left, 0...1).
    func color(atNormalized point: CGPoint) -> Color {
        let x = min(width - 1, max(0, Int(point.x * CGFloat(width))))
        let y = min(height - 1, max(0, Int(point.y * CGFloat(height))))
        let i = (y * width + x) * 4
        let a = CGFloat(pixels[i + 3]) / 255
        // Un-premultiply so fully opaque and translucent pixels report their true color.
        let r = a > 0 ? CGFloat(pixels[i]) / 255 / a : 0
        let g = a > 0 ? CGFloat(pixels[i + 1]) / 255 / a : 0
        let b = a > 0 ? CGFloat(pixels[i + 2]) / 255 / a : 0
        return Color(.displayP3, red: min(1, r), green: min(1, g), blue: min(1, b))
    }
}

// MARK: - Image loading

enum ImageLoader {

    /// Decodes image data into an orientation-corrected, downsampled `CGImage` suitable for on-screen
    /// color picking. Returns `nil` if the data isn't a decodable image.
    static func cgImage(from data: Data, maxPixelSize: Int = 2048) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // Bake in EXIF orientation.
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Decodes the contents of a security-scoped file URL (e.g. from `.fileImporter`).
    static func cgImage(fromFile url: URL, maxPixelSize: Int = 2048) -> CGImage? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return cgImage(from: data, maxPixelSize: maxPixelSize)
    }
}

// MARK: - Picker view

struct ImageColorPickerView: View {

    let cgImage: CGImage
    var onPick: (Color) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sampler: ImagePixelSampler?
    /// The current touch point, in the container's coordinate space. `nil` until the image has been laid out.
    @State private var touch: CGPoint?
    @State private var sampledColor: Color = .clear

    private var imageSize: CGSize { CGSize(width: cgImage.width, height: cgImage.height) }

    init(cgImage: CGImage, onPick: @escaping (Color) -> Void) {
        self.cgImage = cgImage
        self.onPick = onPick
        _sampler = State(initialValue: ImagePixelSampler(cgImage: cgImage))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let fitted = fittedRect(container: geo.size)
                    ZStack(alignment: .topLeading) {
                        Image(decorative: cgImage, scale: 1, orientation: .up)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: fitted.width, height: fitted.height)
                            .position(x: fitted.midX, y: fitted.midY)

                        if let touch {
                            loupe(at: touch, fitted: fitted)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { setTouch($0.location, fitted: fitted) }
                    )
                    .onAppear {
                        if touch == nil {
                            setTouch(CGPoint(x: fitted.midX, y: fitted.midY), fitted: fitted)
                        }
                    }
                }
                .background(.background.secondary)

                swatchBar
            }
            .navigationTitle("Pick Color")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use", systemImage: "checkmark") {
                        onPick(sampledColor)
                        dismiss()
                    }
                }
            }
        }
    }

    private var swatchBar: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(sampledColor)
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            Text("Drag over the image to sample a color.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    // MARK: Loupe

    private func loupe(at point: CGPoint, fitted: CGRect) -> some View {
        let diameter: CGFloat = 104
        let zoom: CGFloat = 8
        let local = CGPoint(x: point.x - fitted.minX, y: point.y - fitted.minY)

        return Image(decorative: cgImage, scale: 1, orientation: .up)
            .resizable()
            .interpolation(.none)
            .frame(width: fitted.width * zoom, height: fitted.height * zoom)
            // Center the magnified touch point within the loupe circle.
            .offset(x: fitted.width * zoom / 2 - local.x * zoom,
                    y: fitted.height * zoom / 2 - local.y * zoom)
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(crosshair)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .overlay(Circle().strokeBorder(sampledColor, lineWidth: 2).padding(3))
            .shadow(radius: 4)
            .position(x: point.x, y: point.y - diameter * 0.75)
            .allowsHitTesting(false)
    }

    private var crosshair: some View {
        ZStack {
            Rectangle().frame(width: 1).blendMode(.difference)
            Rectangle().frame(height: 1).blendMode(.difference)
        }
        .foregroundStyle(.white)
    }

    // MARK: Geometry & sampling

    /// The aspect-fit rect the image occupies inside `container`.
    private func fittedRect(container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height)
    }

    private func setTouch(_ point: CGPoint, fitted: CGRect) {
        guard fitted.width > 0, fitted.height > 0 else { return }
        let clamped = CGPoint(
            x: min(fitted.maxX, max(fitted.minX, point.x)),
            y: min(fitted.maxY, max(fitted.minY, point.y)))
        touch = clamped
        let normalized = CGPoint(
            x: (clamped.x - fitted.minX) / fitted.width,
            y: (clamped.y - fitted.minY) / fitted.height)
        sampledColor = sampler?.color(atNormalized: normalized) ?? .clear
    }
}

// MARK: - Camera capture (iOS)

#if os(iOS)
/// Presents a full-screen camera that captures a photo with the **Constant Color** API, so the
/// sampled color stays accurate regardless of the ambient light's color cast. Hands back an
/// orientation-baked `CGImage`.
struct CameraPicker: UIViewControllerRepresentable {

    var onCapture: (CGImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ConstantColorCameraViewController {
        let controller = ConstantColorCameraViewController()
        controller.onCapture = { image in
            onCapture(image)
            dismiss()
        }
        controller.onCancel = { dismiss() }
        return controller
    }

    func updateUIViewController(_ uiViewController: ConstantColorCameraViewController, context: Context) {}
}

/// A minimal AVFoundation camera. Constant Color capture fires the flash to neutralize the ambient
/// light's tint — a request `UIImagePickerController` can't make — which is exactly what a
/// color-picking app wants from a photo.
final class ConstantColorCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    var onCapture: ((CGImage) -> Void)?
    var onCancel: (() -> Void)?

    // Touched only on `sessionQueue`, which serializes all access, so the isolation is hand-managed.
    private nonisolated(unsafe) let session = AVCaptureSession()
    private nonisolated(unsafe) let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.256arts.palette-3d.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        addControls()
        setUpRotation()

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            sessionQueue.async { self.configureSession() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: Session

    private nonisolated func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.addOutput(photoOutput)

        // Opt the output into Constant Color; each shot's settings request it too.
        if photoOutput.isConstantColorSupported {
            photoOutput.isConstantColorEnabled = true
        }
        session.commitConfiguration()
        session.startRunning()
    }

    // MARK: Rotation

    /// Keeps the preview upright as the device rotates. Fetches its own reference to the shared
    /// capture device so nothing non-`Sendable` has to cross off the capture queue.
    private func setUpRotation() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        applyPreviewRotation()
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.applyPreviewRotation() }
        }
    }

    private func applyPreviewRotation() {
        guard let coordinator = rotationCoordinator,
              let connection = previewLayer.connection else { return }
        let angle = coordinator.videoRotationAngleForHorizonLevelPreview
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    // MARK: Controls

    private func addControls() {
        // Classic shutter: a filled disc inside a thin ring.
        let ring = UIView()
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.backgroundColor = .clear
        ring.layer.borderColor = UIColor.white.cgColor
        ring.layer.borderWidth = 4
        ring.layer.cornerRadius = 37
        ring.isUserInteractionEnabled = false

        let shutter = UIButton(type: .custom)
        shutter.translatesAutoresizingMaskIntoConstraints = false
        shutter.backgroundColor = .white
        shutter.layer.cornerRadius = 30
        shutter.accessibilityLabel = "Capture"
        shutter.addTarget(self, action: #selector(capture), for: .touchUpInside)

        let cancel = UIButton(type: .system)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.setTitle("Cancel", for: .normal)
        cancel.tintColor = .white
        cancel.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cancel.addTarget(self, action: #selector(cancel(_:)), for: .touchUpInside)

        view.addSubview(ring)
        view.addSubview(shutter)
        view.addSubview(cancel)

        NSLayoutConstraint.activate([
            ring.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ring.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            ring.widthAnchor.constraint(equalToConstant: 74),
            ring.heightAnchor.constraint(equalToConstant: 74),

            shutter.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            shutter.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            shutter.widthAnchor.constraint(equalToConstant: 60),
            shutter.heightAnchor.constraint(equalToConstant: 60),

            cancel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            cancel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
        ])
    }

    @objc private func capture() {
        // Read the capture rotation on the main actor (the coordinator lives there).
        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture
        sessionQueue.async { [self] in
            if let angle, let connection = photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            let settings = AVCapturePhotoSettings()
            if photoOutput.isConstantColorEnabled {
                settings.isConstantColorEnabled = true
                // Deliver an ordinary photo if a constant color result can't be produced.
                settings.isConstantColorFallbackPhotoDeliveryEnabled = true
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    @objc private func cancel(_ sender: UIButton) {
        onCancel?()
    }

    // MARK: Capture delegate

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // `fileDataRepresentation()` carries EXIF orientation, which `ImageLoader` bakes into the pixels.
        guard error == nil,
              let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in
            if let cgImage = ImageLoader.cgImage(from: data) {
                onCapture?(cgImage)
            }
        }
    }
}
#endif
