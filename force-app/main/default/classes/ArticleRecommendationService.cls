public class ArticleRecommendationService {

    // This class represents a Knowledge Article
    public class Article {
        public String Title { get; set; }
        public String Url { get; set; }

        public Article(String title, String url) {
            this.Title = title;
            this.Url = url;
        }
    }

    // This method returns a list of sample articles
    public static List<Article> getSampleArticles() {
        List<Article> articles = new List<Article>();
        articles.add(new Article('How to Reset Your Password', 'https://de1721199447250.lightning.force.com/lightning/r/Knowledge__kav/ka0am0000011hePAAQ/view?ws=%2Flightning%2Fr%2FCase%2F500am00000GURcfAAH%2Fview'));
        articles.add(new Article('Troubleshooting Login Issues', 'https://de1721199447250.lightning.force.com/lightning/r/Knowledge__kav/ka0am0000011he9AAA/view?ws=%2Flightning%2Fr%2FCase%2F500am00000GUCNWAA5%2Fview'));
        articles.add(new Article('Updating Your Account Information', 'https://de1721199447250.lightning.force.com/lightning/r/Knowledge__kav/ka0am0000011heNAAQ/view?ws=%2Flightning%2Fr%2FCase%2F500am00000GU3aNAAT%2Fview'));
        return articles;
    }

    // This method returns a formatted string with article recommendations
    public static String getFormattedArticleRecommendations(List<Article> articles) {
        String recommendations = 'Here are some articles that might help you:\n';
        for (Integer i = 0; i < articles.size(); i++) {
            recommendations += (i + 1) + '. ' + articles[i].Title + ' - ' + articles[i].Url + '\n';
        }
        return recommendations;
    }
}