# Chính sách quyền riêng tư của osmGradus

Cập nhật lần cuối: ngày 11 tháng 11 năm 2026

“osmGradus” (sau đây gọi là “Ứng dụng”) xử lý thông tin người dùng như sau. Nhà phát triển Ứng dụng không vận hành máy chủ riêng và không thực hiện quảng cáo, phân tích hành vi hay theo dõi xuyên ứng dụng.

Bản tiếng Nhật là bản chính thức. Nếu có khác biệt giữa bản tiếng Việt và bản tiếng Nhật, bản tiếng Nhật sẽ được ưu tiên.

## 1. Dữ liệu Ứng dụng xử lý

Tùy theo thao tác của người dùng, Ứng dụng xử lý các dữ liệu sau trên thiết bị.

- Âm thanh ghi âm, bản ghi lời nói do nhận dạng giọng nói tạo ra
- Kết quả chấm điểm lời nói, đánh giá phát âm, câu trả lời nhận được từ AI
- Từ vựng, bài luyện tập, đề bài, bài đọc dài do người dùng đăng ký, và nội dung người dùng nhập cho từng đề bài (tóm tắt, PREP, v.v.)
- Câu trả lời nhập bằng bàn phím trong bài kiểm tra từ vựng
- Từ khóa tìm kiếm Podcast, URL đã đăng ký, thông tin chương trình, vị trí phát
- Cài đặt ứng dụng như ngôn ngữ, đọc to, giao diện
- Nhật ký chẩn đoán cho biết trạng thái xử lý nhận dạng giọng nói (không bao gồm nội dung đã nhận dạng)

Ứng dụng không yêu cầu họ tên, địa chỉ, địa chỉ email, số điện thoại, danh bạ hay vị trí làm thông tin hồ sơ. Tuy nhiên, lời nói người dùng ghi âm và bản ghi lời nói có thể chứa họ tên hoặc thông tin cá nhân khác mà chính người dùng đã nói.

## 2. Ghi âm và nhận dạng giọng nói

Khi luyện phát âm và chấm điểm lời nói, Ứng dụng chỉ ghi âm khi người dùng thao tác micro hoặc bắt đầu bộ hẹn giờ luyện tập. Để chuyển âm thanh ghi âm thành văn bản, Ứng dụng chuyển âm thanh cho Speech Recognition của Apple Inc. trên iOS, và cho dịch vụ nhận dạng giọng nói được cài đặt trên thiết bị đối với Android.

Tùy thiết bị, hệ điều hành, ngôn ngữ và cài đặt của người dùng, âm thanh ghi âm có thể được gửi đến máy chủ của Apple hoặc của nhà cung cấp dịch vụ nhận dạng giọng nói và được xử lý trên đám mây. Trên Android, nếu không thể dùng nhận dạng trực tuyến, Ứng dụng sẽ xử lý bằng mô hình Vosk trên thiết bị.

Trước khi dùng nhận dạng giọng nói lần đầu, Ứng dụng giải thích trong ứng dụng về dữ liệu được gửi, nơi nhận và mục đích, và xin sự đồng ý rõ ràng của người dùng. Nếu không đồng ý, người dùng vẫn có thể dùng các chức năng không cần nhận dạng giọng nói. Có thể rút lại sự đồng ý tại “Cài đặt > Quyền riêng tư & Dữ liệu”.

Về cách Apple xử lý dữ liệu, vui lòng xem [Chính sách quyền riêng tư của Apple](https://www.apple.com/legal/privacy/). Với nhận dạng giọng nói trên Android, chính sách quyền riêng tư của nhà cung cấp dịch vụ nhận dạng giọng nói được cài đặt trên thiết bị sẽ được áp dụng.

## 3. Gửi đến chế độ AI của Google

Ứng dụng không có máy chủ AI do nhà phát triển vận hành hay API AI riêng. Chỉ khi người dùng chọn dùng các chức năng dưới đây, Ứng dụng mới mở Google Search (chế độ AI) do Google LLC cung cấp trên trình duyệt bên ngoài để yêu cầu đánh giá tham khảo, lời khuyên hoặc tạo nội dung học.

### 3-1. Đánh giá và lời khuyên về kết quả luyện tập (bao gồm câu trả lời của người dùng)

| Chức năng | Dữ liệu được gửi | Mục đích |
|---|---|---|
| Kiểm tra phát âm Tầng V (10 câu ngắn) | 10 đề bài, cách đọc, biểu thức phát âm cần đánh giá, bản ghi lời nói cho từng câu | Đánh giá tham khảo về xu hướng phát âm (つ, hàng ざ, hàng ら, âm dài, âm ngắt, nhịp điệu, rơi âm) |
| Đọc to bài dài Tầng V | Đoạn đầu của bài dài, bản ghi lời nói khi đọc to (một phần ở đầu) | Như trên |
| Trả lời đề bài Tầng V | Đề bài, bản ghi câu trả lời | Như trên |
| Kiểm tra từ vựng Tầng I | Từ được hỏi, cách đọc, câu trả lời của người dùng (bản ghi lời nói hoặc nhập bằng bàn phím) | Đánh giá tham khảo về vốn từ vựng |
| Đánh giá PREP và độ trúng đích Tầng IV | Đề bài, bản ghi câu trả lời | Đánh giá tham khảo về cấu trúc câu trả lời (PREP) và mức độ trả lời đúng trọng tâm đề bài |
| Tổng kết đề bài | Đề bài và nội dung đã nhập, ghi lại cho đề bài đó ở Tầng I–V (từ vựng đã đăng ký, tóm tắt, kết luận – lý do – ví dụ, điểm của từng tầng, v.v.) | Lời khuyên tổng quát cho từng đề bài |
| Bảng điều khiển | Tối đa 3 kết quả gần nhất cho mỗi loại: kết quả chấm điểm Tầng IV (bản ghi lời nói, cấp độ tham khảo, độ trúng đích, PREP, v.v.), kết quả kiểm tra phát âm Tầng V (điểm theo từng nhóm, nhận xét, v.v.), kết quả kiểm tra từ vựng Tầng I | Lời khuyên tổng quát cho toàn bộ quá trình luyện tập |

Ở mọi chức năng, âm thanh ghi âm không được gửi đến Google. Tuy nhiên, bản ghi lời nói, nội dung nhập bằng bàn phím và nội dung người dùng ghi lại có thể chứa họ tên hoặc thông tin cá nhân khác mà người dùng đã nói hoặc viết.

### 3-2. Tạo nội dung học (bao gồm văn bản, từ do người dùng chọn)

| Chức năng | Dữ liệu được gửi | Mục đích |
|---|---|---|
| Trích xuất từ từ đề bài Tầng I | Đề bài | Trích xuất từ cho bài kiểm tra từ vựng |
| Câu trả lời mẫu Tầng II, IV | Đề bài | Tạo câu trả lời mẫu dài khoảng 45 giây khi nói |
| Câu luyện phát âm liên quan đến đề bài Tầng V | Đề bài | Tạo câu ngắn để luyện phát âm |
| Tạo bài đọc dài | Từ khóa người dùng nhập, cấp độ JLPT, văn phong, độ dài ước tính | Tạo bài đọc |
| Thêm bản dịch cho bài đọc dài | Các từ người dùng đã chọn | Lấy cách đọc, nghĩa và câu ví dụ |

Đề bài bao gồm cả đề bài có sẵn trong Ứng dụng và đề bài do người dùng thêm hoặc chỉnh sửa.

### 3-3. Cách gửi và sự đồng ý

Mọi lần gửi đều được thực hiện bằng cách thêm chỉ dẫn về ngôn ngữ trả lời và định dạng đầu ra vào dữ liệu trên, đặt vào truy vấn của URL Google Search và mở bằng trình duyệt bên ngoài. Nếu nội dung quá dài so với URL, yêu cầu sẽ được sao chép vào bộ nhớ tạm (clipboard) để người dùng dán vào ô tìm kiếm. Nội dung tìm kiếm có thể được lưu trong lịch sử trình duyệt hoặc lịch sử tìm kiếm của Tài khoản Google đang đăng nhập.

Mỗi lần gửi, Ứng dụng giải thích trong ứng dụng về dữ liệu được gửi, nơi nhận (Google LLC), mục đích và khả năng nội dung được lưu trong lịch sử, và chỉ gửi khi người dùng chọn “Đồng ý và gửi đến Google”. Nếu người dùng hủy, Ứng dụng không gửi đến Google và không ghi vào bộ nhớ tạm.

Chỉ khi người dùng sao chép câu trả lời của Google và quay lại Ứng dụng, Ứng dụng mới đọc bộ nhớ tạm để nhập câu trả lời và lưu trên thiết bị. Ứng dụng không gửi nội dung đã đọc đến bất kỳ dịch vụ bên ngoài nào khác.

Việc sử dụng, lưu giữ và xóa dữ liệu đã gửi đến Google tuân theo [Chính sách quyền riêng tư của Google](https://policies.google.com/privacy) và cài đặt Tài khoản Google của người dùng.

## 4. Tạo nội dung bằng lời nhắc cố định qua Google AI

Ở các chức năng thêm đề bài, thêm bài luyện phát âm và thêm từ vựng (chỉ gồm các cấp độ JLPT người dùng chọn), Ứng dụng chỉ gửi lời nhắc cố định đã chuẩn bị sẵn đến Google Search (chế độ AI). Lời nhắc cố định này không chứa bản ghi âm, bản ghi lời nói hay dữ liệu người dùng khác. Khi người dùng sao chép câu trả lời của Google, Ứng dụng đọc bộ nhớ tạm để nhập nội dung. Ứng dụng không gửi nội dung đã đọc đến bất kỳ dịch vụ bên ngoài nào khác.

## 5. Podcast và nội dung bên ngoài

Khi tìm kiếm Podcast, Ứng dụng gửi từ khóa tìm kiếm đến iTunes Search API của Apple Inc. Khi cập nhật hoặc phát Podcast đã đăng ký, Ứng dụng kết nối trực tiếp đến nơi phát hành Podcast. Tại nơi kết nối, địa chỉ IP, thời gian truy cập, nội dung được yêu cầu, v.v. có thể được xử lý dưới dạng nhật ký truyền thông.

## 6. Lưu trữ trên thiết bị và thời gian lưu giữ

Bản ghi lời nói, kết quả chấm điểm, đánh giá phát âm, câu trả lời của AI, sổ từ vựng, thông tin Podcast, cài đặt, v.v. được lưu trên thiết bị. Nhà phát triển không truy cập từ xa vào các nội dung này.

- Tệp ghi âm: bản ghi âm gần nhất được giữ dưới dạng một tệp cố định và bị ghi đè ở lần ghi âm tiếp theo. Tệp bị xóa khi đặt lại bài luyện tập hoặc khi đặt lại toàn bộ dữ liệu.
- Lịch sử chấm điểm và kiểm tra phát âm: được giữ cho đến khi người dùng xóa hoặc xóa Ứng dụng.
- Nhật ký chẩn đoán nhận dạng giọng nói: giữ tối đa 200 mục trên thiết bị.

Người dùng có thể xóa dữ liệu trên thiết bị và tệp ghi âm bằng cách xóa từng mục lịch sử, xóa toàn bộ kết quả đánh giá, hoặc dùng “Cài đặt > Đặt lại toàn bộ dữ liệu”.

## 7. Sao lưu và chia sẻ

Khi người dùng xuất dữ liệu, Ứng dụng tạo tệp JSON từ dữ liệu trên thiết bị và chuyển cho bảng chia sẻ của hệ điều hành. Người dùng tự chọn nơi chia sẻ.

Chỉ khi người dùng bật “Cài đặt > Đồng bộ bằng iCloud” trên iPhone, Ứng dụng mới lưu bản ghi lời nói, kết quả chấm điểm, sổ từ vựng, đề bài, chương trình và tập Podcast (vị trí phát, trạng thái đã phát, v.v.), cài đặt, v.v. vào iCloud của chính người dùng (bộ lưu trữ khóa – giá trị iCloud của Apple Inc.) và đồng bộ giữa các thiết bị dùng cùng Apple ID. Ngôn ngữ hiển thị, việc hiển thị màn hình hướng dẫn, sự đồng ý gửi âm thanh và tệp ghi âm không được đồng bộ. Dữ liệu đồng bộ nằm trong tài khoản iCloud của người dùng và nhà phát triển không truy cập. Khi tắt, Ứng dụng không gửi hoặc nhận dữ liệu từ đó trở đi.

Nếu bật sao lưu thiết bị như iCloud, dữ liệu ứng dụng có thể được lưu lên đám mây bởi chức năng của hệ điều hành. Nhà phát triển không truy cập các bản sao lưu này.

## 8. Bảo vệ bởi bên thứ ba

Ứng dụng không gửi dữ liệu cá nhân đến bên thứ ba khi chưa giải thích trước và chưa có sự đồng ý của người dùng. Với các dịch vụ bên thứ ba được sử dụng, nhà phát triển xem xét chính sách quyền riêng tư và biện pháp bảo mật đã công bố, và chỉ dùng những dịch vụ cung cấp mức bảo vệ tương đương hoặc cao hơn Chính sách này. Mỗi bên thứ ba bảo vệ dữ liệu theo chính sách quyền riêng tư của mình và pháp luật hiện hành.

Ứng dụng không truy cập thông tin xác thực hay dữ liệu của dịch vụ bên thứ ba, và không bán hoặc chia sẻ dữ liệu cho mục đích quảng cáo.

## 9. Rút lại sự đồng ý và xóa dữ liệu ở bên thứ ba

Có thể rút lại sự đồng ý dùng nhận dạng giọng nói tại “Cài đặt > Quyền riêng tư & Dữ liệu”. Sau khi rút lại, Ứng dụng sẽ hỏi lại sự đồng ý ở lần dùng tiếp theo.

Để xóa dữ liệu đã gửi đến Apple, Google hoặc nhà cung cấp dịch vụ nhận dạng giọng nói trên Android, vui lòng dùng màn hình quản lý quyền riêng tư hoặc kênh liên hệ của từng nhà cung cấp. Lịch sử tìm kiếm Google có thể được quản lý tại “Hoạt động của tôi” (My Activity) trong Tài khoản Google.

## 10. Quảng cáo, phân tích và theo dõi

Ứng dụng không tích hợp SDK quảng cáo, SDK phân tích truy cập hay SDK thu thập sự cố, và không theo dõi người dùng xuyên qua ứng dụng hoặc trang web của công ty khác.

## 11. Liên hệ

- Tên nhà phát triển: osm
- Liên hệ: <https://x.com/ushiqy9a?s=21&t=pUfdHqgPxlddKfUyZtv2kA>

Khi thay đổi Chính sách này, ngày cập nhật lần cuối của tài liệu công bố sẽ được cập nhật. Nếu có thay đổi quan trọng về mục đích sử dụng dữ liệu hoặc việc chia sẻ với bên thứ ba, Ứng dụng sẽ giải thích lại trong ứng dụng và xin sự đồng ý khi cần thiết.
