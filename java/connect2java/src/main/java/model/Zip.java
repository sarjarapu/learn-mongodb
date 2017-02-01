package model;

import org.bson.types.ObjectId;

/**
 * Created by shyamarjarapu on 1/10/17.
 */
public class Zip {
    private ObjectId id;
    private String city;
    private String state;
    private String zip;
    private int pop;


    public ObjectId getId() {
        return id;
    }

    public void setId(ObjectId id) {
        this.id = id;
    }

    public String getCity() {
        return city;
    }

    public void setCity(String city) {
        this.city = city;
    }

    public String getState() {
        return state;
    }

    public void setState(String state) {
        this.state = state;
    }

    public String getZip() {
        return zip;
    }

    public void setZip(String zip) {
        this.zip = zip;
    }

    public int getPop() {
        return pop;
    }

    public void setPop(int pop) {
        this.pop = pop;
    }


    @Override
    public String toString() {
        return "Place: " + this.city + ", " + this.state + " Population: " + this.pop;
    }

}
