//
//  FullScreenImageViewer.swift
//  WorkSurvivalGuide
//
//  全屏图片查看器（纯 UIKit）：居中适配、左右滑动、双指缩放、长按/按钮保存
//

import SwiftUI
import Photos

// MARK: - SwiftUI 入口（接口保持不变）

struct FullScreenImageViewer: View {
    let items: [(imageUrl: String?, imageBase64: String?)]
    let initialIndex: Int
    let baseURL: String
    let onDismiss: () -> Void
    
    /// 单图便捷初始化（兼容旧调用）
    init(imageUrl: String?, imageBase64: String?, baseURL: String, onDismiss: @escaping () -> Void) {
        self.items = [(imageUrl, imageBase64)]
        self.initialIndex = 0
        self.baseURL = baseURL
        self.onDismiss = onDismiss
    }
    
    /// 多图初始化（支持左右滑动）
    init(items: [(imageUrl: String?, imageBase64: String?)], initialIndex: Int, baseURL: String, onDismiss: @escaping () -> Void) {
        self.items = items.isEmpty ? [(imageUrl: nil, imageBase64: nil)] : items
        self.initialIndex = min(max(0, initialIndex), max(0, items.count - 1))
        self.baseURL = baseURL
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        FullScreenImageRepresentable(
            items: items,
            initialIndex: initialIndex,
            baseURL: baseURL,
            onDismiss: onDismiss
        )
        .ignoresSafeArea(.all)
    }
}

// MARK: - UIViewControllerRepresentable 包装

private struct FullScreenImageRepresentable: UIViewControllerRepresentable {
    let items: [(imageUrl: String?, imageBase64: String?)]
    let initialIndex: Int
    let baseURL: String
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> FullScreenImageViewController {
        let vc = FullScreenImageViewController()
        vc.items = items
        vc.currentIndex = initialIndex
        vc.baseURL = baseURL
        vc.onDismiss = onDismiss
        return vc
    }
    
    func updateUIViewController(_ vc: FullScreenImageViewController, context: Context) {
        vc.items = items
        vc.baseURL = baseURL
        vc.onDismiss = onDismiss
    }
}

// MARK: - 纯 UIKit 全屏控制器（UIPageViewController + 缩放页）

private final class FullScreenImageViewController: UIViewController {
    var items: [(imageUrl: String?, imageBase64: String?)] = []
    var currentIndex: Int = 0
    var baseURL: String = ""
    var onDismiss: (() -> Void)?
    
    private var pageViewController: UIPageViewController!
    private var pageControl: UIPageControl?
    private var hintLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        edgesForExtendedLayout = .all
        
        pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 20]
        )
        pageViewController.dataSource = self
        pageViewController.delegate = self
        pageViewController.view.backgroundColor = .black
        
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        pageViewController.didMove(toParent: self)
        
        if let first = pageAtIndex(currentIndex) {
            pageViewController.setViewControllers([first], direction: .forward, animated: false)
        }
        
        setupTopBar()
        setupBottomBar()
    }
    
    private func setupTopBar() {
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = .white.withAlphaComponent(0.9)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        
        let saveBtn = UIButton(type: .system)
        saveBtn.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
        saveBtn.tintColor = .white.withAlphaComponent(0.9)
        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView(arrangedSubviews: [saveBtn, closeBtn])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupBottomBar() {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = max(1, items.count)
        pageControl.currentPage = currentIndex
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = .white.withAlphaComponent(0.5)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        self.pageControl = pageControl
        
        let hintLabel = UILabel()
        hintLabel.text = "左右滑动切换 · 双指缩放 · 长按保存"
        hintLabel.font = .systemFont(ofSize: 12, weight: .regular)
        hintLabel.textColor = .white.withAlphaComponent(0.5)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        self.hintLabel = hintLabel
        
        let stack = UIStackView(arrangedSubviews: [pageControl, hintLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -34),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        if items.count <= 1 {
            pageControl.isHidden = true
        }
    }
    
    private func pageAtIndex(_ index: Int) -> ZoomableImagePageViewController? {
        guard index >= 0, index < items.count else { return nil }
        let item = items[index]
        let vc = ZoomableImagePageViewController()
        vc.imageUrl = item.imageUrl
        vc.imageBase64 = item.imageBase64
        vc.pageIndex = index
        vc.onLongPress = { [weak self] in self?.showSaveAction() }
        return vc
    }
    
    @objc private func closeTapped() {
        onDismiss?()
    }
    
    @objc private func saveTapped() {
        showSaveAction()
    }
    
    private func showSaveAction() {
        let alert = UIAlertController(title: "保存图片", message: "将当前图片保存到设备相册", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "保存到相册", style: .default) { [weak self] _ in
            self?.saveCurrentImage()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }
    
    private func saveCurrentImage() {
        guard let img = currentPageImage() else {
            showSaveResult("图片尚未加载完成，请稍后再试")
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    self?.showSaveResult("需要相册权限才能保存图片")
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: img)
                } completionHandler: { [weak self] success, error in
                    DispatchQueue.main.async {
                        self?.showSaveResult(success ? "已保存到相册" : (error?.localizedDescription ?? "保存失败"))
                    }
                }
            }
        }
    }
    
    private func currentPageImage() -> UIImage? {
        guard currentIndex >= 0, currentIndex < items.count else { return nil }
        let item = items[currentIndex]
        if let url = item.imageUrl, let img = ImageCacheManager.shared.image(for: url) { return img }
        if let b64 = item.imageBase64, !b64.isEmpty, let img = ImageCacheManager.shared.image(forBase64: b64) { return img }
        if let b64 = item.imageBase64, !b64.isEmpty,
           let data = Data(base64Encoded: b64),
           let img = UIImage(data: data) { return img }
        return nil
    }
    
    private func showSaveResult(_ message: String) {
        let alert = UIAlertController(title: "保存结果", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

extension FullScreenImageViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? ZoomableImagePageViewController else { return nil }
        return pageAtIndex(vc.pageIndex - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? ZoomableImagePageViewController else { return nil }
        return pageAtIndex(vc.pageIndex + 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed, let vc = pageViewController.viewControllers?.first as? ZoomableImagePageViewController {
            currentIndex = vc.pageIndex
            pageControl?.currentPage = currentIndex
        }
    }
}

// MARK: - 单页缩放视图控制器（minimumZoomScale 法实现 aspect fit）

private final class ZoomableImagePageViewController: UIViewController, UIScrollViewDelegate {
    var imageUrl: String?
    var imageBase64: String?
    var pageIndex: Int = 0
    var onLongPress: (() -> Void)?
    
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var lastLoadedUrl: String?
    private var lastLoadedBase64: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.minimumZoomScale = 0.25
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        view.addGestureRecognizer(longPress)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        updateImageIfNeeded()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let img = imageView.image {
            updateZoomAndLayout(for: img)
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
    }
    
    private func updateImageIfNeeded() {
        if let url = imageUrl, let img = ImageCacheManager.shared.image(for: url) {
            if lastLoadedUrl != url {
                applyImage(img)
                lastLoadedUrl = url
                lastLoadedBase64 = nil
            }
            return
        }
        if let b64 = imageBase64, !b64.isEmpty, let img = ImageCacheManager.shared.image(forBase64: b64) {
            if lastLoadedBase64 != b64 {
                applyImage(img)
                lastLoadedBase64 = b64
                lastLoadedUrl = nil
            }
            return
        }
        if let b64 = imageBase64, !b64.isEmpty,
           let data = Data(base64Encoded: b64),
           let img = UIImage(data: data) {
            if lastLoadedBase64 != b64 {
                applyImage(img)
                ImageCacheManager.shared.cache(img, forBase64: b64)
                lastLoadedBase64 = b64
                lastLoadedUrl = nil
            }
            return
        }
        if let urlString = imageUrl, lastLoadedUrl != urlString {
            lastLoadedUrl = urlString
            loadFromURL(urlString)
        }
    }
    
    private func loadFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        if urlString.contains("/api/v1/"), let token = KeychainManager.shared.getToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self, let data, let img = UIImage(data: data) else { return }
            ImageCacheManager.shared.cache(img, for: urlString)
            DispatchQueue.main.async {
                if self.imageUrl == urlString {
                    self.applyImage(img)
                }
            }
        }.resume()
    }
    
    private func applyImage(_ img: UIImage) {
        imageView.image = img
        updateZoomAndLayout(for: img)
    }
    
    /// 使用 minimumZoomScale 法实现初始 aspect fit（参考 Apple PhotoScroller）
    private func updateZoomAndLayout(for img: UIImage) {
        let imgSize = img.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }
        
        imageView.frame = CGRect(origin: .zero, size: imgSize)
        scrollView.contentSize = imgSize
        
        let svSize = scrollView.bounds.size
        guard svSize.width > 0, svSize.height > 0 else { return }
        
        let wRatio = svSize.width / imgSize.width
        let hRatio = svSize.height / imgSize.height
        let minScale = min(wRatio, hRatio)
        
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(minScale * 4, 4.0)
        scrollView.zoomScale = minScale
        centerImageView()
    }
    
    private func centerImageView() {
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        imageView.frame = frameToCenter
    }
    
    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        if g.state == .began { onLongPress?() }
    }
    
    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            scrollView.setZoomScale(min(2, scrollView.maximumZoomScale), animated: true)
        }
    }
}
