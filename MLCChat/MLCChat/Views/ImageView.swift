import SwiftUI

struct ImageView: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 280)
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}

struct ImageView_Previews: PreviewProvider {
    static var previews: some View {
        ImageView(image: UIImage(systemName: "photo")!)
    }
}
