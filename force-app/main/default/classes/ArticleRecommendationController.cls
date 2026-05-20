public class ArticleRecommendationController {
    public static void showArticleRecommendations() {
        // Get sample articles from the service
        List<ArticleRecommendationService.Article> articles = ArticleRecommendationService.getSampleArticles();
        
        // Get the formatted recommendations
        String recommendations = ArticleRecommendationService.getFormattedArticleRecommendations(articles);
        
        // Display the recommendations (for example, in a debug log)
        System.debug(recommendations);
        
        // If you want to return the recommendations, you can do so:
        // return recommendations;
    }
}