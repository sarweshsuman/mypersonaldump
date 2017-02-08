import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.Optional;
import java.util.stream.Stream;


public class Java8Practice {
	public static void main(String args[]) throws Exception {
		FileReader fis = new FileReader("C:/Users/id832037/Downloads/RTLS_20161012_1476257654562.txt");
		BufferedReader br = new BufferedReader(fis);
		String line="";
		ArrayList<String> list = new ArrayList<String>();
		while((line = br.readLine()) != null ){
			list.add(line);
		}
		Optional<String> result=list.stream().map(str -> str.split(",")[1]).reduce((a,b) -> a+b);
		System.out.println(result.get());
	}
}
