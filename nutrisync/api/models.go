package main

type Location struct {
	Latitude  *float64 `json:"latitude"`
	Longitude *float64 `json:"longitude"`
}

type MeasurementInput struct {
	Username     string   `json:"username"`
	User         string   `json:"user"`
	Timestamp    string   `json:"timestamp"`
	N            *float64 `json:"n"`
	P            *float64 `json:"p"`
	K            *float64 `json:"k"`
	Ph           *float64 `json:"ph"`
	Ec           *float64 `json:"ec"`
	Temp         *float64 `json:"temp"`
	Hum          *float64 `json:"hum"`
	LocationName string   `json:"location_name"`

	Location Location `json:"location"`

	Note        *string `json:"note,omitempty"`         // Field Note
	ProjectName *string `json:"project_name,omitempty"` // ✅ FITUR BARU: Project Name
}

type Measurement struct {
	ID           string   `json:"_id"`
	User         string   `json:"user"`
	Timestamp    string   `json:"timestamp"`
	N            *float64 `json:"n"`
	P            *float64 `json:"p"`
	K            *float64 `json:"k"`
	Ph           *float64 `json:"ph"`
	Ec           *float64 `json:"ec"`
	Temp         *float64 `json:"temp"`
	Hum          *float64 `json:"hum"`
	Location     Location `json:"location"`
	LocationName string   `json:"location_name"`

	Note        *string `json:"note,omitempty"`         // Field Note
	ProjectName *string `json:"project_name,omitempty"` // ✅ FITUR BARU: Project Name
}

type DashboardResponse struct {
	TotalCount int           `json:"total_count"`
	Latest     *Measurement  `json:"latest,omitempty"`
	DataList   []Measurement `json:"data_list"`
}
